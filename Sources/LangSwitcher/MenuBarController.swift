import AppKit

/// Manages the menu bar status item and wires it to the keyboard interceptor.
@MainActor
final class MenuBarController {

    private let statusItem: NSStatusItem
    private let interceptor: KeyboardInterceptor
    private var toggleItem: NSMenuItem!

    init() {
        interceptor = KeyboardInterceptor()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard",
                                   accessibilityDescription: "LangSwitch")
        }

        buildMenu()
        updateIcon()
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        toggleItem = NSMenuItem(title: "Enabled",
                                action: #selector(toggleEnabled),
                                keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = interceptor.isEnabled ? .on : .off
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About LangSwitch",
                               action: #selector(showAbout),
                               keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit",
                              action: #selector(quitApp),
                              keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        interceptor.isEnabled.toggle()
        toggleItem.state = interceptor.isEnabled ? .on : .off
        updateIcon()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "LangSwitch 1.0"
        alert.informativeText = """
            Automatically converts Russian (Cyrillic) text typed \
            on an English QWERTY keyboard back to English.
            """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let symbolName = interceptor.isEnabled ? "keyboard" : "keyboard.chevron.compact.left"
        button.image = NSImage(systemSymbolName: symbolName,
                               accessibilityDescription: "LangSwitch")
        // Add a subtle visual cue: dim when disabled
        button.appearsDisabled = !interceptor.isEnabled
    }
}
