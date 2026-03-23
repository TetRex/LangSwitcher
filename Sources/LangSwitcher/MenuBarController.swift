import AppKit

/// Manages the menu bar status item and wires it to the keyboard interceptor.
@MainActor
final class MenuBarController {

    private let statusItem: NSStatusItem
    private let interceptor: KeyboardInterceptor
    private var settingsController: SettingsWindowController?
    private var welcomeController: WelcomeWindowController?
    private var aboutController: AboutWindowController?

    init() {
        interceptor = KeyboardInterceptor()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard",
                                   accessibilityDescription: "LangSwitcher")
        }

        buildMenu()

        // Show welcome only if Accessibility permission hasn't been granted yet.
        if !WelcomeWindowController.isAccessibilityGranted {
            showWelcome()
        }
    }

    // MARK: - Menu

    private static func menuItem(title: String,
                                  symbol: String,
                                  action: Selector,
                                  key: String,
                                  target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }

    private func buildMenu() {
        let menu = NSMenu()

        menu.addItem(Self.menuItem(title: "Preferences",
                                   symbol: "gearshape",
                                   action: #selector(openSettings),
                                   key: ",",
                                   target: self))

        menu.addItem(Self.menuItem(title: "About",
                                   symbol: "info.circle",
                                   action: #selector(showAbout),
                                   key: "",
                                   target: self))

        menu.addItem(.separator())

        menu.addItem(.separator())

        menu.addItem(Self.menuItem(title: "Quit",
                                   symbol: "xmark.circle",
                                   action: #selector(quitApp),
                                   key: "q",
                                   target: self))

        statusItem.menu = menu
    }

    // MARK: - Actions

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
        if aboutController == nil {
            aboutController = AboutWindowController(correctionCount: interceptor.correctionCount)
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: aboutController?.window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.aboutController = nil }
            }
        }
        aboutController?.showWindow(nil)
        aboutController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func showWelcome() {
        if welcomeController == nil {
            welcomeController = WelcomeWindowController(
                currentKeyCode: interceptor.forceConvertKeyCode,
                currentModifiers: interceptor.forceConvertModifiers
            )
            welcomeController?.onShortcutChanged = { [weak self] keyCode, modifiers in
                self?.interceptor.forceConvertKeyCode = keyCode
                self?.interceptor.forceConvertModifiers = modifiers
            }
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: welcomeController?.window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.welcomeController = nil
                    // Retry starting the event tap after the user finishes setup.
                    self?.interceptor.startEventTap()
                }
            }
        }
        welcomeController?.showWindow(nil)
        welcomeController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

}
