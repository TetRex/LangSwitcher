import AppKit

@main
@MainActor
struct LangSwitchApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // no Dock icon

        let delegate = AppDelegate()
        app.delegate = delegate

        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
    }
}
