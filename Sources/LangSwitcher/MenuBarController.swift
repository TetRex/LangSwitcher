import AppKit

/// Manages the menu bar status item and wires it to the keyboard interceptor.
@MainActor
final class MenuBarController {

    private let statusItem: NSStatusItem
    private let interceptor: KeyboardInterceptor
    private var toggleItem: NSMenuItem!
    private var settingsController: SettingsWindowController?
    private var welcomeController: WelcomeWindowController?

    init() {
        interceptor = KeyboardInterceptor()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard",
                                   accessibilityDescription: "LangSwitch")
        }

        buildMenu()
        updateIcon()

        // Show the welcome window when Accessibility permission is not granted.
        if !WelcomeWindowController.isAccessibilityGranted {
            showWelcome()
        }
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

        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(openSettings),
                                  keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let help = NSMenuItem(title: "How to Use…",
                              action: #selector(openWelcome),
                              keyEquivalent: "")
        help.target = self
        menu.addItem(help)

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

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                currentKeyCode: interceptor.forceConvertKeyCode,
                currentModifiers: interceptor.forceConvertModifiers
            )
            settingsController?.onShortcutChanged = { [weak self] keyCode, modifiers in
                self?.interceptor.forceConvertKeyCode = keyCode
                self?.interceptor.forceConvertModifiers = modifiers
            }
            // Release the controller when the window is closed to free memory.
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: settingsController?.window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.settingsController = nil
                }
            }
        }
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openWelcome() {
        showWelcome()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "LangSwitch 0.0.2"
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

    private func showWelcome() {
        if welcomeController == nil {
            welcomeController = WelcomeWindowController()
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: welcomeController?.window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.welcomeController = nil
                }
            }
        }
        welcomeController?.showWindow(nil)
        welcomeController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
