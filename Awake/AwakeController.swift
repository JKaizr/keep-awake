import AppKit

/// Owns the whole "keep awake" state: which assertions are held and until when.
///
/// The timer works with a wall-clock end date (`endsAt`), not a countdown,
/// so it stays correct across sleep/wake, App Nap and clock ticks being late.
/// Nothing about a running session is persisted: after a relaunch or restart
/// the app always starts in the safe "off" state.
@MainActor
final class AwakeController: NSObject, ObservableObject {
    static let presetMinutes = [30, 60, 120, 240, 480]

    @Published private(set) var isActive = false
    @Published private(set) var endsAt: Date?
    /// Preset that started the current session (nil when extended or indefinite).
    @Published private(set) var selectedMinutes: Int?
    @Published private(set) var now = Date()
    @Published private(set) var keepDisplayOn: Bool
    @Published private(set) var lastMinutes: Int

    /// Called on every state change and on every tick while active.
    var onChange: (() -> Void)?

    private var systemAssertion: PowerAssertion?
    private var displayAssertion: PowerAssertion?
    private var appNapActivity: NSObjectProtocol?
    private var ticker: Timer?

    private enum Keys {
        static let keepDisplayOn = "keepDisplayOn"
        static let lastMinutes = "lastMinutes"
    }

    override init() {
        let defaults = UserDefaults.standard
        keepDisplayOn = defaults.bool(forKey: Keys.keepDisplayOn)
        let saved = defaults.integer(forKey: Keys.lastMinutes)
        lastMinutes = Self.presetMinutes.contains(saved) ? saved : 60
        super.init()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake(_:)),
            name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    // MARK: - Derived state

    var isIndefinite: Bool { isActive && endsAt == nil }

    var remaining: TimeInterval? {
        guard isActive, let endsAt else { return nil }
        return max(0, endsAt.timeIntervalSince(now))
    }

    // MARK: - Actions

    /// - Parameter minutes: nil = until turned off.
    func start(minutes: Int?) {
        if let minutes {
            lastMinutes = minutes
            UserDefaults.standard.set(minutes, forKey: Keys.lastMinutes)
        }
        start(duration: minutes.map { TimeInterval($0 * 60) }, preset: minutes)
    }

    /// - Parameter duration: seconds, nil = until turned off.
    func start(duration: TimeInterval?, preset: Int? = nil) {
        now = Date()
        isActive = true
        selectedMinutes = preset
        endsAt = duration.map { now.addingTimeInterval($0) }
        guard applyAssertions() else { return }
        beginAppNapProtection()
        startTicker()
        changed()
    }

    func extend(minutes: Int = 60) {
        guard isActive, let endsAt else { return }
        self.endsAt = endsAt.addingTimeInterval(TimeInterval(minutes * 60))
        selectedMinutes = nil
        _ = applyAssertions()
        changed()
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        endsAt = nil
        selectedMinutes = nil
        systemAssertion = nil   // deinit releases the assertion
        displayAssertion = nil
        stopTicker()
        endAppNapProtection()
        changed()
    }

    func setKeepDisplayOn(_ on: Bool) {
        keepDisplayOn = on
        UserDefaults.standard.set(on, forKey: Keys.keepDisplayOn)
        if isActive { _ = applyAssertions() }
        changed()
    }

    // MARK: - Assertions

    /// (Re)creates the assertions for the current settings. The new ones are
    /// created before the old ones are released, so there is never a gap.
    @discardableResult
    private func applyAssertions() -> Bool {
        // Safety net: macOS drops the assertion itself one minute after our
        // own end time, even if this app were somehow frozen.
        let backstop = remaining.map { $0 + 60 }

        guard let system = PowerAssertion(.preventIdleSystemSleep,
                                          reason: "Awake is keeping your Mac awake",
                                          timeout: backstop) else {
            stop()
            NSSound.beep()
            return false
        }
        let display = keepDisplayOn
            ? PowerAssertion(.preventIdleDisplaySleep,
                             reason: "Awake is keeping your display on",
                             timeout: backstop)
            : nil

        systemAssertion = system
        displayAssertion = display
        return true
    }

    // MARK: - Timer

    private func startTicker() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1, target: self, selector: #selector(tick),
                          userInfo: nil, repeats: true)
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common) // keeps ticking while the menu is open
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    @objc private func tick() {
        now = Date()
        if let endsAt, now >= endsAt {
            stop()
        } else {
            changed()
        }
    }

    @objc private func systemDidWake(_ note: Notification) {
        // The Mac was put to sleep anyway (lid closed, Apple menu → Sleep).
        // Re-evaluate against the wall clock right away.
        if isActive { tick() }
    }

    /// Keeps our timer from being throttled by App Nap. Does not affect sleep.
    private func beginAppNapProtection() {
        guard appNapActivity == nil else { return }
        appNapActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Awake countdown"
        )
    }

    private func endAppNapProtection() {
        if let appNapActivity { ProcessInfo.processInfo.endActivity(appNapActivity) }
        appNapActivity = nil
    }

    private func changed() {
        onChange?()
    }
}

// MARK: - Human-readable status

extension AwakeController {
    var headline: String {
        guard isActive else { return "Vypnuto" }
        return keepDisplayOn ? "Mac i displej vzhůru" : "Mac vzhůru · displej smí zhasnout"
    }

    var detail: String {
        guard isActive else { return "Mac se uspává podle nastavení systému" }
        guard let endsAt, let remaining else { return "Dokud nevypneš · ∞" }
        return "Zbývá \(Format.remaining(remaining)) · do \(Format.time(endsAt))"
    }

    /// Short text next to the menu bar icon.
    var menuBarTitle: String {
        guard isActive else { return "" }
        guard let remaining else { return "∞" }
        return Format.clock(remaining)
    }
}

enum Format {
    /// Czech accusative, reads well after "na": "na 30 minut", "na 1 hodinu", "na 2 hodiny", "na 8 hodin".
    static func duration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) minut" }
        let hours = minutes / 60
        switch hours {
        case 1: return "1 hodinu"
        case 2...4: return "\(hours) hodiny"
        default: return "\(hours) hodin"
        }
    }

    private static func roundedUpMinutes(_ seconds: TimeInterval) -> Int {
        Int((seconds / 60).rounded(.up))
    }

    /// "1:42"
    static func clock(_ seconds: TimeInterval) -> String {
        let m = roundedUpMinutes(seconds)
        return String(format: "%d:%02d", m / 60, m % 60)
    }

    /// "1 h 42 min", "2 h", "42 min"
    static func remaining(_ seconds: TimeInterval) -> String {
        let m = roundedUpMinutes(seconds)
        let h = m / 60, r = m % 60
        if h == 0 { return "\(r) min" }
        if r == 0 { return "\(h) h" }
        return "\(h) h \(r) min"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
