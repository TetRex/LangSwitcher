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
        removeWindowCloseObserver(at: \.settingsCloseObserver)
        removeWindowCloseObserver(at: \.welcomeCloseObserver)
        removeWindowCloseObserver(at: \.aboutCloseObserver)
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
            observeWindowClose(for: settingsController?.window,
                               storeIn: \.settingsCloseObserver) { [weak self] in
                self?.settingsController = nil
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
            aboutController = AboutWindowController()
            observeWindowClose(for: aboutController?.window,
                               storeIn: \.aboutCloseObserver) { [weak self] in
                self?.aboutController = nil
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
            observeWindowClose(for: welcomeController?.window,
                               storeIn: \.welcomeCloseObserver) { [weak self] in
                self?.welcomeController = nil
                // Retry starting the event tap after the user finishes setup.
                self?.interceptor.startEventTap()
            }
        }
        welcomeController?.showWindow(nil)
        welcomeController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func observeWindowClose(for window: NSWindow?,
                                    storeIn keyPath: ReferenceWritableKeyPath<MenuBarController, NSObjectProtocol?>,
                                    onClose: @escaping @MainActor () -> Void) {
        removeWindowCloseObserver(at: keyPath)
        guard let window else { return }

        self[keyPath: keyPath] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.removeWindowCloseObserver(at: keyPath)
                onClose()
            }
        }
    }

    private func removeWindowCloseObserver(at keyPath: ReferenceWritableKeyPath<MenuBarController, NSObjectProtocol?>) {
        if let observer = self[keyPath: keyPath] {
            NotificationCenter.default.removeObserver(observer)
            self[keyPath: keyPath] = nil
        }
    }

}
