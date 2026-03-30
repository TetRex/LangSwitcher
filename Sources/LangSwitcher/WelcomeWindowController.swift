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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .black
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildUI()
        updateShortcutDisplay()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UIs

    private static func makeSectionHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text.uppercased())
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = NSColor(white: 0.45, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private static func makeSeparator() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(white: 0.18, alpha: 1).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    /// Small numbered circle badge for step indicators.
    private static func makeStepBadge(_ number: String) -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.85).cgColor
        badge.layer?.cornerRadius = 10
        badge.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: number)
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])
        return badge
    }

    private static func makeFeatureRow(symbol: String, title: String, description: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = NSColor.systemBlue.withAlphaComponent(0.9)
        icon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(icon)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = NSColor(white: 0.48, alpha: 1)
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descLabel)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 1),
            icon.widthAnchor.constraint(equalToConstant: 15),
            icon.heightAnchor.constraint(equalToConstant: 15),

            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 9),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            descLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        return container
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor

        // — Titlebar placeholder —
        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // — Hero: icon + name + subtitle —
        let appIconView = NSImageView()
        appIconView.image = NSImage(named: "AppIconImage")
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(appIconView)

        let appNameLabel = NSTextField(labelWithString: "LangSwitcher")
        appNameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        appNameLabel.textColor = .white
        appNameLabel.alignment = .center
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(appNameLabel)

        let subtitleLabel = NSTextField(labelWithString: "Smart keyboard layout switcher for macOS")
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = NSColor(white: 0.5, alpha: 1)
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        // — Feature rows —
        let feature1 = Self.makeFeatureRow(
            symbol: "wand.and.sparkles",
            title: "Auto-Convert",
            description: "Detects mistyped words and fixes the layout automatically on Space or Enter"
        )
        contentView.addSubview(feature1)

        let feature2 = Self.makeFeatureRow(
            symbol: "command",
            title: "Force Convert",
            description: "Press your shortcut mid-word to instantly switch the current word's layout"
        )
        contentView.addSubview(feature2)

        let feature3 = Self.makeFeatureRow(
            symbol: "text.cursor",
            title: "Text Shortcuts",
            description: "Type a trigger word and it expands into a full phrase automatically"
        )
        contentView.addSubview(feature3)

        // — Separator 1 —
        let sep1 = Self.makeSeparator()
        contentView.addSubview(sep1)

        // — Step 1: Shortcut —
        let badge1 = Self.makeStepBadge("1")
        contentView.addSubview(badge1)

        let shortcutHeader = Self.makeSectionHeader("Force‑Convert Shortcut")
        contentView.addSubview(shortcutHeader)

        let shortcutHintLabel = NSTextField(labelWithString: "Press while typing to instantly convert the current word to the correct layout.")
        shortcutHintLabel.font = .systemFont(ofSize: 12)
        shortcutHintLabel.textColor = NSColor(white: 0.55, alpha: 1)
        shortcutHintLabel.maximumNumberOfLines = 3
        shortcutHintLabel.lineBreakMode = .byWordWrapping
        shortcutHintLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shortcutHintLabel)

        let shortcutContainer = NSView()
        shortcutContainer.wantsLayer = true
        shortcutContainer.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        shortcutContainer.layer?.cornerRadius = 8
        shortcutContainer.layer?.borderWidth = 1
        shortcutContainer.layer?.borderColor = NSColor(white: 0.28, alpha: 1).cgColor
        shortcutContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shortcutContainer)

        shortcutField.isEditable = false
        shortcutField.isSelectable = false
        shortcutField.alignment = .center
        shortcutField.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        shortcutField.isBezeled = false
        shortcutField.drawsBackground = false
        shortcutField.textColor = .white
        shortcutField.translatesAutoresizingMaskIntoConstraints = false
        shortcutContainer.addSubview(shortcutField)

        NSLayoutConstraint.activate([
            shortcutField.centerYAnchor.constraint(equalTo: shortcutContainer.centerYAnchor),
            shortcutField.leadingAnchor.constraint(equalTo: shortcutContainer.leadingAnchor, constant: 6),
            shortcutField.trailingAnchor.constraint(equalTo: shortcutContainer.trailingAnchor, constant: -6),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(startRecordingShortcut))
        shortcutContainer.addGestureRecognizer(click)

        // — Separator 2 —
        let sep2 = Self.makeSeparator()
        contentView.addSubview(sep2)

        // — Step 2: Accessibility —
        let badge2 = Self.makeStepBadge("2")
        contentView.addSubview(badge2)

        let accessHeader = Self.makeSectionHeader("Accessibility Permission")
        contentView.addSubview(accessHeader)

        let grantHelpLabel = NSTextField(labelWithString: "Required to read and replace typed text. Enable LangSwitcher in System Settings.")
        grantHelpLabel.font = .systemFont(ofSize: 12)
        grantHelpLabel.textColor = NSColor(white: 0.55, alpha: 1)
        grantHelpLabel.maximumNumberOfLines = 2
        grantHelpLabel.lineBreakMode = .byWordWrapping
        grantHelpLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(grantHelpLabel)

        let grantButton = NSButton(title: "Open Settings", target: self, action: #selector(grantAccessibility))
        grantButton.isBordered = false
        grantButton.wantsLayer = true
        grantButton.layer?.backgroundColor = NSColor(white: 0.18, alpha: 1).cgColor
        grantButton.layer?.cornerRadius = 7
        grantButton.layer?.borderWidth = 1
        grantButton.layer?.borderColor = NSColor(white: 0.35, alpha: 1).cgColor
        grantButton.layer?.masksToBounds = true
        grantButton.attributedTitle = NSAttributedString(
            string: "Open Settings",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white,
            ]
        )
        grantButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(grantButton)

        // — Separator 3 —
        let sep3 = Self.makeSeparator()
        contentView.addSubview(sep3)

        // — Start button —
        let startButton = NSButton(title: "Start", target: self, action: #selector(dismissWelcome))
        startButton.isBordered = false
        startButton.wantsLayer = true
        startButton.layer?.backgroundColor = NSColor.systemBlue.cgColor
        startButton.layer?.cornerRadius = 8
        startButton.layer?.masksToBounds = true
        startButton.attributedTitle = NSAttributedString(
            string: "Start",
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
        )
        startButton.keyEquivalent = "\r"
        startButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(startButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),

            // Hero area
            appIconView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 22),
            appIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            appIconView.widthAnchor.constraint(equalToConstant: 80),
            appIconView.heightAnchor.constraint(equalToConstant: 80),

            appNameLabel.topAnchor.constraint(equalTo: appIconView.bottomAnchor, constant: 10),
            appNameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 4),
            subtitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // Feature rows
            feature1.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            feature1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            feature1.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),

            feature2.topAnchor.constraint(equalTo: feature1.bottomAnchor, constant: 12),
            feature2.leadingAnchor.constraint(equalTo: feature1.leadingAnchor),
            feature2.trailingAnchor.constraint(equalTo: feature1.trailingAnchor),

            feature3.topAnchor.constraint(equalTo: feature2.bottomAnchor, constant: 12),
            feature3.leadingAnchor.constraint(equalTo: feature1.leadingAnchor),
            feature3.trailingAnchor.constraint(equalTo: feature1.trailingAnchor),

            sep1.topAnchor.constraint(equalTo: feature3.bottomAnchor, constant: 20),
            sep1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            sep1.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            sep1.heightAnchor.constraint(equalToConstant: 1),

            // Step 1 header row
            badge1.topAnchor.constraint(equalTo: sep1.bottomAnchor, constant: 16),
            badge1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            badge1.widthAnchor.constraint(equalToConstant: 20),
            badge1.heightAnchor.constraint(equalToConstant: 20),

            shortcutHeader.centerYAnchor.constraint(equalTo: badge1.centerYAnchor),
            shortcutHeader.leadingAnchor.constraint(equalTo: badge1.trailingAnchor, constant: 8),

            // Hint text (left) + shortcut box (right)
            shortcutHintLabel.topAnchor.constraint(equalTo: badge1.bottomAnchor, constant: 10),
            shortcutHintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            shortcutHintLabel.trailingAnchor.constraint(equalTo: shortcutContainer.leadingAnchor, constant: -12),

            shortcutContainer.centerYAnchor.constraint(equalTo: shortcutHintLabel.centerYAnchor),
            shortcutContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            shortcutContainer.widthAnchor.constraint(equalToConstant: 100),
            shortcutContainer.heightAnchor.constraint(equalToConstant: 34),

            sep2.topAnchor.constraint(equalTo: shortcutHintLabel.bottomAnchor, constant: 18),
            sep2.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            sep2.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            sep2.heightAnchor.constraint(equalToConstant: 1),

            // Step 2 header row
            badge2.topAnchor.constraint(equalTo: sep2.bottomAnchor, constant: 16),
            badge2.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            badge2.widthAnchor.constraint(equalToConstant: 20),
            badge2.heightAnchor.constraint(equalToConstant: 20),

            accessHeader.centerYAnchor.constraint(equalTo: badge2.centerYAnchor),
            accessHeader.leadingAnchor.constraint(equalTo: badge2.trailingAnchor, constant: 8),

            grantHelpLabel.topAnchor.constraint(equalTo: badge2.bottomAnchor, constant: 10),
            grantHelpLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            grantHelpLabel.trailingAnchor.constraint(equalTo: grantButton.leadingAnchor, constant: -12),

            grantButton.centerYAnchor.constraint(equalTo: grantHelpLabel.centerYAnchor),
            grantButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            grantButton.widthAnchor.constraint(equalToConstant: 120),
            grantButton.heightAnchor.constraint(equalToConstant: 30),

            sep3.topAnchor.constraint(equalTo: grantHelpLabel.bottomAnchor, constant: 18),
            sep3.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            sep3.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            sep3.heightAnchor.constraint(equalToConstant: 1),

            startButton.topAnchor.constraint(greaterThanOrEqualTo: sep3.bottomAnchor, constant: 16),
            startButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 160),
            startButton.heightAnchor.constraint(equalToConstant: 36),
            startButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
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
