import AppKit

/// A first-run setup window that lets users pick a shortcut,
/// grant Accessibility access, and confirm the app is ready.
@MainActor
final class WelcomeWindowController: NSWindowController {

    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    var onShortcutChanged: ((_ keyCode: Int, _ modifiers: UInt64) -> Void)?

    private let shortcutContainer = NSView()
    private let shortcutField = NSTextField(labelWithString: "")
    private let recordShortcutButton = NSButton()
    private let shortcutHintLabel = NSTextField(labelWithString: "")
    private let statusSummaryLabel = NSTextField(labelWithString: "")
    private let grantButton = NSButton()
    private let startButton = NSButton()
    private let startHintLabel = NSTextField(labelWithString: "")
    private let shortcutRecorder = ShortcutRecorder()

    private let shortcutStatusRow = SetupStatusRowView(title: "Shortcut")
    private let accessibilityStatusRow = SetupStatusRowView(title: "Accessibility")
    private let readinessStatusRow = SetupStatusRowView(title: "App Ready")

    private var currentKeyCode: Int
    private var currentModifiers: UInt64

    init(currentKeyCode: Int, currentModifiers: UInt64) {
        self.currentKeyCode = currentKeyCode
        self.currentModifiers = currentModifiers

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to LangSwitcher"
        window.toolbarStyle = .unified
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor

        super.init(window: window)
        window.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        buildUI()
        refreshSetupState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private static func makeSectionHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private static func makeSecondaryLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let backgroundView = NSVisualEffectView()
        backgroundView.material = .windowBackground
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundView)

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(contentStack)

        let iconView = NSImageView()
        iconView.image = NSImage(named: "AppIconImage")
            ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 72),
            iconView.heightAnchor.constraint(equalToConstant: 72),
        ])

        let titleLabel = NSTextField(labelWithString: "Welcome to LangSwitcher")
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .labelColor

        let subtitleLabel = Self.makeSecondaryLabel(
            "Pick your shortcut, grant Accessibility access, and confirm the app is ready to start correcting layout mistakes."
        )

        let heroStack = NSStackView(views: [iconView, titleLabel, subtitleLabel])
        heroStack.orientation = .vertical
        heroStack.alignment = .centerX
        heroStack.spacing = 8
        contentStack.addArrangedSubview(heroStack)

        let featureStack = NSStackView(views: [
            makeFeatureRow(symbol: "wand.and.sparkles", title: "Auto-correct on Space or Return"),
            makeFeatureRow(symbol: "command", title: "Force convert the current word instantly"),
            makeFeatureRow(symbol: "text.cursor", title: "Expand short triggers into full phrases"),
        ])
        featureStack.orientation = .vertical
        featureStack.alignment = .leading
        featureStack.spacing = 8
        contentStack.addArrangedSubview(featureStack)

        contentStack.addArrangedSubview(makeShortcutCard())
        contentStack.addArrangedSubview(makeAccessibilityCard())
        contentStack.addArrangedSubview(makeStatusCard())

        configurePrimaryButton(startButton, title: "Start LangSwitcher")
        startButton.target = self
        startButton.action = #selector(dismissWelcome)

        startHintLabel.font = .systemFont(ofSize: 12)
        startHintLabel.textColor = .secondaryLabelColor
        startHintLabel.maximumNumberOfLines = 0
        startHintLabel.lineBreakMode = .byWordWrapping

        let footerStack = NSStackView(views: [startButton, startHintLabel])
        footerStack.orientation = .vertical
        footerStack.alignment = .leading
        footerStack.spacing = 8
        contentStack.addArrangedSubview(footerStack)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: backgroundView.bottomAnchor, constant: -24),

            startButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])
    }

    private func makeShortcutCard() -> NSView {
        let card = makeCardView()

        let header = Self.makeSectionHeader("1. Choose a Force Convert Shortcut")
        let description = Self.makeSecondaryLabel(
            "Use this while typing whenever you want to flip the current word without waiting for Space."
        )

        shortcutContainer.wantsLayer = true
        shortcutContainer.layer?.cornerRadius = 10
        shortcutContainer.layer?.borderWidth = 1
        shortcutContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        shortcutContainer.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        shortcutContainer.translatesAutoresizingMaskIntoConstraints = false
        shortcutContainer.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(startRecordingShortcut)))

        shortcutField.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        shortcutField.textColor = .labelColor
        shortcutField.alignment = .center
        shortcutField.lineBreakMode = .byTruncatingTail
        shortcutField.translatesAutoresizingMaskIntoConstraints = false
        shortcutContainer.addSubview(shortcutField)

        configureSecondaryButton(recordShortcutButton, title: "Record Shortcut", symbol: "pencil.line")
        recordShortcutButton.target = self
        recordShortcutButton.action = #selector(startRecordingShortcut)

        let controlsRow = NSStackView(views: [shortcutContainer, recordShortcutButton])
        controlsRow.orientation = .horizontal
        controlsRow.alignment = .centerY
        controlsRow.spacing = 10

        shortcutHintLabel.font = .systemFont(ofSize: 12)
        shortcutHintLabel.textColor = .secondaryLabelColor
        shortcutHintLabel.maximumNumberOfLines = 0
        shortcutHintLabel.lineBreakMode = .byWordWrapping

        let stack = NSStackView(views: [header, description, controlsRow, shortcutHintLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            shortcutContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            shortcutContainer.heightAnchor.constraint(equalToConstant: 38),
            shortcutField.leadingAnchor.constraint(equalTo: shortcutContainer.leadingAnchor, constant: 10),
            shortcutField.trailingAnchor.constraint(equalTo: shortcutContainer.trailingAnchor, constant: -10),
            shortcutField.centerYAnchor.constraint(equalTo: shortcutContainer.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeAccessibilityCard() -> NSView {
        let card = makeCardView()

        let header = Self.makeSectionHeader("2. Grant Accessibility Permission")
        let description = Self.makeSecondaryLabel(
            "LangSwitcher needs Accessibility access to observe your typing and replace mistyped words."
        )

        configureSecondaryButton(grantButton, title: "Open Accessibility Settings", symbol: "gearshape")
        grantButton.target = self
        grantButton.action = #selector(grantAccessibility)

        let stack = NSStackView(views: [header, description, grantButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeStatusCard() -> NSView {
        let card = makeCardView()

        let header = Self.makeSectionHeader("Setup Status")
        statusSummaryLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusSummaryLabel.textColor = .secondaryLabelColor
        statusSummaryLabel.maximumNumberOfLines = 0
        statusSummaryLabel.lineBreakMode = .byWordWrapping

        let rowsStack = NSStackView(views: [shortcutStatusRow, accessibilityStatusRow, readinessStatusRow, statusSummaryLabel])
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 10

        let stack = NSStackView(views: [header, rowsStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makeCardView() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.88).cgColor
        return card
    }

    private func makeFeatureRow(symbol: String, title: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        icon.contentTintColor = .controlAccentColor

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor

        row.addArrangedSubview(icon)
        row.addArrangedSubview(label)
        return row
    }

    private func configurePrimaryButton(_ button: NSButton, title: String) {
        button.title = title
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.contentTintColor = .controlAccentColor
    }

    private func configureSecondaryButton(_ button: NSButton, title: String, symbol: String) {
        button.title = title
        button.bezelStyle = .rounded
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.contentTintColor = .controlAccentColor
    }

    private func refreshShortcutDisplay() {
        let shortcut = ShortcutConfiguration.displayName(keyCode: currentKeyCode, modifiers: currentModifiers)
        shortcutField.stringValue = shortcutRecorder.isRecording ? "Recording…" : shortcut
        shortcutField.textColor = shortcutRecorder.isRecording ? .systemRed : .labelColor
        shortcutContainer.layer?.borderColor = (shortcutRecorder.isRecording ? NSColor.systemRed : NSColor.separatorColor).cgColor
        recordShortcutButton.contentTintColor = shortcutRecorder.isRecording ? .systemRed : .controlAccentColor
        shortcutHintLabel.stringValue = shortcutRecorder.isRecording
            ? "Press Escape to cancel, or press the shortcut you want to use."
            : "Click the field or use “Record Shortcut” to change it. Current shortcut: \(shortcut)"
    }

    private func refreshSetupState() {
        let accessibilityGranted = Self.isAccessibilityGranted
        let shortcut = ShortcutConfiguration.displayName(keyCode: currentKeyCode, modifiers: currentModifiers)
        refreshShortcutDisplay()

        shortcutStatusRow.update(
            state: .good,
            detail: "Ready to use: \(shortcut)"
        )

        if accessibilityGranted {
            accessibilityStatusRow.update(
                state: .good,
                detail: "Permission granted. LangSwitcher can watch and replace text."
            )
            readinessStatusRow.update(
                state: .good,
                detail: "Everything is ready. You can start using the app now."
            )
            statusSummaryLabel.stringValue = "Setup complete. LangSwitcher will keep running in the menu bar."
            statusSummaryLabel.textColor = .secondaryLabelColor
            startButton.isEnabled = true
            startHintLabel.stringValue = "You can reopen setup later from the menu bar at any time."
        } else {
            accessibilityStatusRow.update(
                state: .warning,
                detail: "Open Accessibility settings and enable LangSwitcher before continuing."
            )
            readinessStatusRow.update(
                state: .warning,
                detail: "Waiting for Accessibility permission."
            )
            statusSummaryLabel.stringValue = "LangSwitcher cannot start correcting text until Accessibility access is enabled."
            statusSummaryLabel.textColor = .systemOrange
            startButton.isEnabled = false
            startHintLabel.stringValue = "The Start button will unlock as soon as Accessibility permission is granted."
        }
    }

    // MARK: - Shortcut Recording

    @objc private func startRecordingShortcut() {
        refreshShortcutDisplay()
        shortcutField.stringValue = "Recording…"
        shortcutField.textColor = .systemRed
        shortcutContainer.layer?.borderColor = NSColor.systemRed.cgColor
        recordShortcutButton.contentTintColor = .systemRed
        shortcutHintLabel.stringValue = "Press Escape to cancel, or press the shortcut you want to use."

        shortcutRecorder.start { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.refreshSetupState()
            }
        } onShortcut: { [weak self] keyCode, modifiers in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.currentKeyCode = keyCode
                self.currentModifiers = modifiers
                ShortcutConfiguration.save(keyCode: keyCode, modifiers: modifiers)
                self.onShortcutChanged?(keyCode, modifiers)
                self.refreshSetupState()
            }
        }
    }

    func stopShortcutRecording() {
        shortcutRecorder.stop()
        refreshSetupState()
    }

    // MARK: - Actions

    @objc private func handleApplicationDidBecomeActive() {
        refreshSetupState()
    }

    @objc private func grantAccessibility() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: kCFBooleanTrue!] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)

        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    @objc private func dismissWelcome() {
        guard Self.isAccessibilityGranted else { return }
        window?.close()
    }
}

extension WelcomeWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        refreshSetupState()
    }
}

private final class SetupStatusRowView: NSView {
    enum State {
        case good
        case warning
    }

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .labelColor

        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 0
        detailLabel.lineBreakMode = .byWordWrapping

        let labels = NSStackView(views: [titleLabel, detailLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2

        let row = NSStackView(views: [iconView, labels])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(state: State, detail: String) {
        detailLabel.stringValue = detail
        switch state {
        case .good:
            iconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: detail)
            iconView.contentTintColor = .systemGreen
        case .warning:
            iconView.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: detail)
            iconView.contentTintColor = .systemOrange
        }
    }
}
