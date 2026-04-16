import AppKit

/// Manages the menu bar status item and wires it to the keyboard interceptor.
@MainActor
final class MenuBarController {

    private let statusItem: NSStatusItem
    private let interceptor: KeyboardInterceptor
    private var settingsController: SettingsWindowController?
    private var welcomeController: WelcomeWindowController?
    private var aboutController: AboutWindowController?
    private var settingsCloseObserver: NSObjectProtocol?
    private var welcomeCloseObserver: NSObjectProtocol?
    private var aboutCloseObserver: NSObjectProtocol?

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

    deinit {
        if let settingsCloseObserver {
            NotificationCenter.default.removeObserver(settingsCloseObserver)
        }
        if let welcomeCloseObserver {
            NotificationCenter.default.removeObserver(welcomeCloseObserver)
        }
        if let aboutCloseObserver {
            NotificationCenter.default.removeObserver(aboutCloseObserver)
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
            installSettingsCloseObserver(for: settingsController?.window)
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
            aboutController = AboutWindowController()
            installAboutCloseObserver(for: aboutController?.window)
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
            installWelcomeCloseObserver(for: welcomeController?.window)
        }
        welcomeController?.showWindow(nil)
        welcomeController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func installSettingsCloseObserver(for window: NSWindow?) {
        if let settingsCloseObserver {
            NotificationCenter.default.removeObserver(settingsCloseObserver)
            self.settingsCloseObserver = nil
        }
        guard let window else { return }

        settingsCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                if let settingsCloseObserver = self.settingsCloseObserver {
                    NotificationCenter.default.removeObserver(settingsCloseObserver)
                    self.settingsCloseObserver = nil
                }
                self.settingsController = nil
            }
        }
    }

    private func installWelcomeCloseObserver(for window: NSWindow?) {
        if let welcomeCloseObserver {
            NotificationCenter.default.removeObserver(welcomeCloseObserver)
            self.welcomeCloseObserver = nil
        }
        guard let window else { return }

        welcomeCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                if let welcomeCloseObserver = self.welcomeCloseObserver {
                    NotificationCenter.default.removeObserver(welcomeCloseObserver)
                    self.welcomeCloseObserver = nil
                }
                self.welcomeController = nil
                self.interceptor.startEventTap()
            }
        }
    }

    private func installAboutCloseObserver(for window: NSWindow?) {
        if let aboutCloseObserver {
            NotificationCenter.default.removeObserver(aboutCloseObserver)
            self.aboutCloseObserver = nil
        }
        guard let window else { return }

        aboutCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                if let aboutCloseObserver = self.aboutCloseObserver {
                    NotificationCenter.default.removeObserver(aboutCloseObserver)
                    self.aboutCloseObserver = nil
                }
                self.aboutController = nil
            }
        }
    }

}
