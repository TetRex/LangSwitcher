import AppKit

/// Compact About window with app icon, version, and feature summary.
@MainActor
final class AboutWindowController: NSWindowController {

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 340),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "About LangSwitcher"
        window.toolbarStyle = .unifiedCompact
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor

        super.init(window: window)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let backgroundView = NSVisualEffectView()
        backgroundView.material = .windowBackground
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundView)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(stack)

        let iconView = NSImageView()
        iconView.image = NSImage(named: "AppIconImage")
            ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 72),
            iconView.heightAnchor.constraint(equalToConstant: 72),
        ])

        let titleLabel = NSTextField(labelWithString: "LangSwitcher")
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .labelColor

        let versionLabel = NSTextField(labelWithString: appVersionText())
        versionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        versionLabel.textColor = .secondaryLabelColor

        let summaryLabel = NSTextField(labelWithString: "A lightweight menu bar app that fixes keyboard layout mix-ups between English and Cyrillic as you type.")
        summaryLabel.font = .systemFont(ofSize: 13)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.alignment = .center
        summaryLabel.maximumNumberOfLines = 0
        summaryLabel.lineBreakMode = .byWordWrapping

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(versionLabel)
        stack.addArrangedSubview(summaryLabel)
        stack.addArrangedSubview(makeFeaturePills())

        let copyrightLabel = NSTextField(labelWithString: "© \(Calendar.current.component(.year, from: Date())) LangSwitcher")
        copyrightLabel.font = .systemFont(ofSize: 11)
        copyrightLabel.textColor = .tertiaryLabelColor
        stack.addArrangedSubview(copyrightLabel)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: backgroundView.bottomAnchor, constant: -24),
        ])
    }

    private func makeFeaturePills() -> NSView {
        let pills = NSStackView()
        pills.orientation = .vertical
        pills.alignment = .centerX
        pills.spacing = 8

        pills.addArrangedSubview(makePill(symbol: "arrow.2.squarepath", text: "Auto-corrects mistyped layouts"))
        pills.addArrangedSubview(makePill(symbol: "bolt.fill", text: "Supports instant force convert"))
        pills.addArrangedSubview(makePill(symbol: "text.badge.checkmark", text: "Includes text shortcuts"))

        return pills
    }

    private func makePill(symbol: String, text: String) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.9).cgColor
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.separatorColor.cgColor

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: text)
        icon.contentTintColor = .controlAccentColor
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])

        return container
    }

    private func appVersionText() -> String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, build) {
        case let (version?, build?) where version != build:
            return "Version \(version) (\(build))"
        case let (version?, _):
            return "Version \(version)"
        case let (_, build?):
            return "Build \(build)"
        default:
            return "Version unavailable"
        }
    }
}
