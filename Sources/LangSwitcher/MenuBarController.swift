import AppKit

/// Manages the menu bar status item and wires it to the keyboard interceptor.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let interceptor: KeyboardInterceptor
    private let menu = NSMenu()

    private let stateItem = NSMenuItem()
    private let shortcutItem = NSMenuItem()
    private let accessibilityItem = NSMenuItem()
    private let toggleEnabledItem = NSMenuItem()
    private let setupItem = NSMenuItem()

    private var settingsController: SettingsWindowController?
    private var welcomeController: WelcomeWindowController?
    private var aboutController: AboutWindowController?
    private var settingsCloseObserver: NSObjectProtocol?
    private var welcomeCloseObserver: NSObjectProtocol?
    private var aboutCloseObserver: NSObjectProtocol?

    override init() {
        interceptor = KeyboardInterceptor()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "LangSwitcher")
        }

        buildMenu()
        refreshMenuState()

        if !WelcomeWindowController.isAccessibilityGranted {
            showWelcome()
        }
    }

    // MARK: - Menu

    private static func actionItem(title: String,
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
        menu.delegate = self

        for item in [stateItem, shortcutItem, accessibilityItem] {
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        toggleEnabledItem.target = self
        toggleEnabledItem.action = #selector(toggleEnabled)
        menu.addItem(toggleEnabledItem)

        setupItem.target = self
        setupItem.action = #selector(openWelcome)
        menu.addItem(setupItem)

        menu.addItem(Self.actionItem(title: "Preferences",
                                     symbol: "slider.horizontal.3",
                                     action: #selector(openSettings),
                                     key: ",",
                                     target: self))

        menu.addItem(Self.actionItem(title: "About",
                                     symbol: "info.circle",
                                     action: #selector(showAbout),
                                     key: "",
                                     target: self))

        menu.addItem(.separator())

        menu.addItem(Self.actionItem(title: "Quit",
                                     symbol: "xmark.circle",
                                     action: #selector(quitApp),
                                     key: "q",
                                     target: self))

        statusItem.menu = menu
    }

    private func refreshMenuState() {
        let accessibilityGranted = WelcomeWindowController.isAccessibilityGranted

        stateItem.title = interceptor.isEnabled ? "Status: Enabled" : "Status: Paused"
        stateItem.image = NSImage(
            systemSymbolName: interceptor.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill",
            accessibilityDescription: stateItem.title
        )

        let shortcut = ShortcutConfiguration.displayName(
            keyCode: interceptor.forceConvertKeyCode,
            modifiers: interceptor.forceConvertModifiers
        )
        shortcutItem.title = "Force Convert: \(shortcut)"
        shortcutItem.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: shortcutItem.title)

        accessibilityItem.title = accessibilityGranted ? "Accessibility: Granted" : "Accessibility: Needs Setup"
        accessibilityItem.image = NSImage(
            systemSymbolName: accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
            accessibilityDescription: accessibilityItem.title
        )

        toggleEnabledItem.title = interceptor.isEnabled ? "Pause Corrections" : "Resume Corrections"
        toggleEnabledItem.image = NSImage(
            systemSymbolName: interceptor.isEnabled ? "pause.circle" : "play.circle",
            accessibilityDescription: toggleEnabledItem.title
        )

        setupItem.title = accessibilityGranted ? "Show Setup Assistant" : "Complete Setup"
        setupItem.image = NSImage(
            systemSymbolName: accessibilityGranted ? "sparkles" : "wrench.and.screwdriver",
            accessibilityDescription: setupItem.title
        )

        updateStatusButton(accessibilityGranted: accessibilityGranted)
    }

    private func updateStatusButton(accessibilityGranted: Bool) {
        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "LangSwitcher")
        image?.isTemplate = true
        button.image = image

        if !accessibilityGranted {
            button.contentTintColor = .systemOrange
            button.toolTip = "LangSwitcher needs Accessibility permission"
        } else if interceptor.isEnabled {
            button.contentTintColor = .controlAccentColor
            button.toolTip = "LangSwitcher is enabled"
        } else {
            button.contentTintColor = .secondaryLabelColor
            button.toolTip = "LangSwitcher is paused"
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenuState()
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        interceptor.isEnabled.toggle()
        refreshMenuState()
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
                self?.refreshMenuState()
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
                self?.refreshMenuState()
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
                self.settingsController?.stopShortcutRecording()
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
                self.welcomeController?.stopShortcutRecording()
                if let welcomeCloseObserver = self.welcomeCloseObserver {
                    NotificationCenter.default.removeObserver(welcomeCloseObserver)
                    self.welcomeCloseObserver = nil
                }
                self.welcomeController = nil
                self.interceptor.startEventTap()
                self.refreshMenuState()
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
