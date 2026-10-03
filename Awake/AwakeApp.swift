import AppKit

/// Menu-bar-only app: no window, no Dock icon (LSUIElement = YES in Info.plist).
@main
enum AwakeApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AwakeController?
    private var statusMenu: StatusMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = AwakeController()
        self.controller = controller
        if CommandLine.arguments.contains("--selftest") {
            SelfTest.run(controller)
        }
        self.statusMenu = StatusMenu(controller: controller)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // macOS would release the assertions anyway; this just makes it explicit.
        controller?.stop()
    }
}
