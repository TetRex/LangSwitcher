import AppKit
import Carbon.HIToolbox

/// A minimal first-run setup window that lets users pick a shortcut,
/// grant Accessibility access, and start using the app.
@MainActor
final class WelcomeWindowController: NSWindowController {

    /// Returns `true` when the app already has Accessibility permission.
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Called when the user picks a new shortcut.
    var onShortcutChanged: ((_ keyCode: Int, _ modifiers: UInt64) -> Void)?

    private let shortcutField = NSTextField()
    private var isRecording = false
    private var localMonitor: Any?

    private var currentKeyCode: Int
    private var currentModifiers: UInt64

    // MARK: - Init

    init(currentKeyCode: Int, currentModifiers: UInt64) {
        self.currentKeyCode = currentKeyCode
        self.currentModifiers = currentModifiers

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LangSwitcher"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildUI()
        updateShortcutDisplay()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor

        let appIconView = NSImageView()
        let appIcon = Bundle.main.image(forResource: "AppIcon")
            ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap { NSImage(contentsOf: $0) }
            ?? NSApp.applicationIconImage
        appIconView.image = appIcon
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(appIconView)

        let appNameLabel = NSTextField(labelWithString: "LangSwitcher")
        appNameLabel.font = .systemFont(ofSize: 26, weight: .bold)
        appNameLabel.textColor = .white
        appNameLabel.alignment = .center
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(appNameLabel)

        let shortcutLabel = NSTextField(labelWithString: "Shortcut")
        shortcutLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        shortcutLabel.textColor = .white
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shortcutLabel)

        shortcutField.isEditable = false
        shortcutField.isSelectable = false
        shortcutField.alignment = .center
        shortcutField.font = .monospacedSystemFont(ofSize: 18, weight: .medium)
        shortcutField.isBezeled = true
        shortcutField.bezelStyle = .roundedBezel
        shortcutField.textColor = .white
        shortcutField.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        shortcutField.drawsBackground = true
        shortcutField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shortcutField)

        let click = NSClickGestureRecognizer(target: self, action: #selector(startRecordingShortcut))
        shortcutField.addGestureRecognizer(click)

        let grantButton = NSButton(title: "Grant Access",
                                   target: self,
                                   action: #selector(grantAccessibility))
        grantButton.bezelStyle = .rounded
        grantButton.contentTintColor = .white
        grantButton.bezelColor = NSColor(white: 0.2, alpha: 1.0)
        grantButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(grantButton)

        let grantHelpLabel = NSTextField(labelWithString: "Opens Accessibility settings. Turn on LangSwitcher and return here.")
        grantHelpLabel.font = .systemFont(ofSize: 11, weight: .regular)
        grantHelpLabel.textColor = NSColor(white: 0.85, alpha: 1.0)
        grantHelpLabel.alignment = .center
        grantHelpLabel.maximumNumberOfLines = 2
        grantHelpLabel.lineBreakMode = .byWordWrapping
        grantHelpLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(grantHelpLabel)

        let startButton = NSButton(title: "Start",
                                   target: self,
                                   action: #selector(dismissWelcome))
        startButton.isBordered = false
        startButton.wantsLayer = true
        startButton.layer?.backgroundColor = NSColor.systemBlue.cgColor
        startButton.layer?.cornerRadius = 16
        startButton.layer?.masksToBounds = true
        startButton.attributedTitle = NSAttributedString(
            string: "Start",
            attributes: [
                .font: NSFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: NSColor.white
            ]
        )
        startButton.keyEquivalent = "\r"
        startButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(startButton)

        let startButtonWidth: CGFloat = 150
        let startButtonHeight: CGFloat = 70

        NSLayoutConstraint.activate([
            appIconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            appIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            appIconView.widthAnchor.constraint(equalToConstant: 96),
            appIconView.heightAnchor.constraint(equalToConstant: 96),

            appNameLabel.topAnchor.constraint(equalTo: appIconView.bottomAnchor, constant: 12),
            appNameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            shortcutLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 26),
            shortcutLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            shortcutField.topAnchor.constraint(equalTo: shortcutLabel.bottomAnchor, constant: 10),
            shortcutField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            shortcutField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            shortcutField.heightAnchor.constraint(equalToConstant: 46),

            grantButton.topAnchor.constraint(equalTo: shortcutField.bottomAnchor, constant: 18),
            grantButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            grantButton.widthAnchor.constraint(equalToConstant: 120),

            grantHelpLabel.topAnchor.constraint(equalTo: grantButton.bottomAnchor, constant: 8),
            grantHelpLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            grantHelpLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            startButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            startButton.topAnchor.constraint(equalTo: grantHelpLabel.bottomAnchor, constant: 24),
            startButton.widthAnchor.constraint(equalToConstant: startButtonWidth),
            startButton.heightAnchor.constraint(equalToConstant: startButtonHeight),
        ])
    }

    private func updateShortcutDisplay() {
        shortcutField.stringValue = SettingsWindowController.displayName(
            keyCode: currentKeyCode,
            modifiers: currentModifiers
        )
    }

    // MARK: - Shortcut recording

    @objc private func startRecordingShortcut() {
        isRecording = true
        shortcutField.stringValue = "Press shortcut..."

        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.isRecording = false

            if event.keyCode == UInt16(kVK_Escape),
               event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                self.updateShortcutDisplay()
                if let m = self.localMonitor {
                    NSEvent.removeMonitor(m)
                    self.localMonitor = nil
                }
                return nil
            }

            let keyCode = Int(event.keyCode)
            let mods = SettingsWindowController.significantModifiers(UInt64(event.modifierFlags.rawValue))

            self.currentKeyCode = keyCode
            self.currentModifiers = mods
            self.updateShortcutDisplay()

            UserDefaults.standard.set(keyCode, forKey: "ForceConvertKeyCode")
            UserDefaults.standard.set(Int64(bitPattern: mods), forKey: "ForceConvertModifiers")

            self.onShortcutChanged?(keyCode, mods)

            if let m = self.localMonitor {
                NSEvent.removeMonitor(m)
                self.localMonitor = nil
            }
            return nil
        }
    }

    // MARK: - Actions

    @objc private func grantAccessibility() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: kCFBooleanTrue!] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)

        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    @objc private func dismissWelcome() {
        window?.close()
    }
}
