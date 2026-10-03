import Foundation
import IOKit.pwr_mgt

/// Headless functional test of the real controller + IOKit assertions.
/// Run:  /Applications/Awake.app/Contents/MacOS/Awake --selftest
/// It never touches your saved preferences and exits when done (0 = all passed).
@MainActor
enum SelfTest {
    private static var failures = 0

    static func run(_ c: AwakeController) -> Never {
        let savedDisplay = c.keepDisplayOn
        print("Awake self-test — pid \(getpid())\n")

        check("start state is off, no assertions", !c.isActive && held().isEmpty)

        c.setKeepDisplayOn(false)
        c.start(duration: 1800, preset: 30)
        check("start 30 min → system assertion only",
              held() == ["PreventUserIdleSystemSleep"])
        check("menu bar shows 0:30", c.menuBarTitle == "0:30")
        check("system timeout backstop set (~1860 s)",
              (1790...1870).contains(timeout("PreventUserIdleSystemSleep") ?? 0))

        c.setKeepDisplayOn(true)
        check("display on while running → system + display",
              held() == ["PreventUserIdleDisplaySleep", "PreventUserIdleSystemSleep"])

        c.extend(minutes: 60)
        check("extend +1 h → 1:30 left, still 2 assertions",
              c.menuBarTitle == "1:30" && held().count == 2)

        c.setKeepDisplayOn(false)
        check("display off while running → system only",
              held() == ["PreventUserIdleSystemSleep"])

        c.stop()
        check("stop → no assertions, inactive", !c.isActive && held().isEmpty)

        c.start(duration: nil)
        check("indefinite → ∞, system assertion without timeout",
              c.menuBarTitle == "∞" && held() == ["PreventUserIdleSystemSleep"]
                && timeout("PreventUserIdleSystemSleep") == nil)
        c.stop()

        for i in 0..<20 {
            c.setKeepDisplayOn(i % 2 == 0)
            c.start(duration: 3600, preset: 60)
            if i % 3 == 0 { c.start(duration: 7200, preset: 120) } // restart while running
            c.stop()
        }
        check("20× start/stop/restart → nothing leaked", held().isEmpty)

        c.setKeepDisplayOn(true)
        c.start(duration: 3600, preset: 60)
        c.start(duration: 14400, preset: 240)
        check("restart while running → still exactly 2 assertions", held().count == 2)
        c.stop()

        // Timer expiry with a short duration
        c.setKeepDisplayOn(true)
        c.start(duration: 3)
        check("3 s session active", c.isActive && held().count == 2)
        RunLoop.main.run(until: Date().addingTimeInterval(4.5))
        check("after 3 s timer → auto-off, assertions released", !c.isActive && held().isEmpty)

        c.setKeepDisplayOn(savedDisplay)

        // Leave one running so the caller can verify that quitting releases it.
        if CommandLine.arguments.contains("--exit-while-active") {
            c.start(duration: 3600, preset: 60)
            check("left active before exit", held().count >= 1)
        }

        print("\n\(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")")
        exit(failures == 0 ? 0 : 1)
    }

    private static func check(_ name: String, _ ok: Bool) {
        if !ok { failures += 1 }
        print("\(ok ? "✓" : "✗") \(name)\(ok ? "" : "   held=\(held())")")
    }

    /// Assertion types this process currently holds, as reported by macOS itself.
    private static func mine() -> [NSDictionary] {
        var ref: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&ref) == kIOReturnSuccess,
              let dict = ref?.takeRetainedValue() as NSDictionary? else { return [] }
        for (key, value) in dict {
            if let pid = key as? NSNumber, pid.int32Value == getpid() {
                return (value as? [NSDictionary]) ?? []
            }
        }
        return []
    }

    private static func held() -> [String] {
        mine().compactMap { $0["AssertType"] as? String }.sorted()
    }

    private static func timeout(_ type: String) -> Double? {
        guard let a = mine().first(where: { ($0["AssertType"] as? String) == type }),
              let t = a["TimeoutSeconds"] as? NSNumber, t.doubleValue > 0 else { return nil }
        return t.doubleValue
    }
}
