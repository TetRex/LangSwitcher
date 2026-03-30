import AppKit

/// Custom About window with app icon, version, and feature list.
@MainActor
final class AboutWindowController: NSWindowController {

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "About LangSwitcher"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .black
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor

        // App icon
        let iconView = NSImageView()
        iconView.image = NSImage(named: "AppIconImage")
            ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 16
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        // App name
        let nameLabel = NSTextField(labelWithString: "LangSwitcher")
        nameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.alignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        // Version badge
        let versionBadge = makeVersionBadge("Version 0.4.0")
        contentView.addSubview(versionBadge)

        // Separator
        let sep1 = makeSeparator()
        contentView.addSubview(sep1)

        // Feature rows
        let features: [(String, String, String)] = [
            ("arrow.2.squarepath",
             "Cyrillic ⇄ English",
             "Auto-corrects text typed on the wrong Cyrillic or QWERTY layout when you press Space or Enter."),
            ("bolt.fill",
             "Force Convert Shortcut",
             "Press your shortcut mid-word to instantly convert without waiting for Space or Enter."),
            ("text.badge.checkmark",
             "Text Shortcuts",
             "Define custom trigger → expansion pairs for frequently typed text (e.g. \"addr\" → your address)."),
        ]

        var featureRows: [NSView] = []
        for (symbol, title, desc) in features {
            let row = makeFeatureRow(symbol: symbol, title: title, description: desc)
            contentView.addSubview(row)
            featureRows.append(row)
        }

        let sep2 = makeSeparator()
        contentView.addSubview(sep2)

        let copyright = NSTextField(labelWithString: "© 2025 LangSwitcher")
        copyright.font = .systemFont(ofSize: 10)
        copyright.textColor = NSColor(white: 0.3, alpha: 1)
        copyright.alignment = .center
        copyright.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(copyright)

        // MARK: Constraints

        var constraints: [NSLayoutConstraint] = [
            iconView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 24),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 72),
            iconView.heightAnchor.constraint(equalToConstant: 72),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            nameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            versionBadge.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            versionBadge.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            sep1.topAnchor.constraint(equalTo: versionBadge.bottomAnchor, constant: 20),
            sep1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            sep1.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            sep1.heightAnchor.constraint(equalToConstant: 1),
        ]

        // Chain feature rows
        var prevBottom = sep1.bottomAnchor
        for (i, row) in featureRows.enumerated() {
            constraints += [
                row.topAnchor.constraint(equalTo: prevBottom, constant: i == 0 ? 16 : 10),
                row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
                row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            ]
            prevBottom = row.bottomAnchor
        }

        constraints += [
            sep2.topAnchor.constraint(equalTo: prevBottom, constant: 16),
            sep2.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            sep2.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            sep2.heightAnchor.constraint(equalToConstant: 1),

            copyright.topAnchor.constraint(equalTo: sep2.bottomAnchor, constant: 12),
            copyright.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            copyright.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Helpers

    private func makeSeparator() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(white: 0.18, alpha: 1).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    /// Small pill-shaped version badge.
    private func makeVersionBadge(_ text: String) -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor(white: 0.14, alpha: 1).cgColor
        badge.layer?.cornerRadius = 9
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = NSColor(white: 0.28, alpha: 1).cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: text)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = NSColor(white: 0.6, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: badge.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -10),
        ])

        return badge
    }

    private func makeFeatureRow(symbol: String, title: String, description: String) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        // Icon container — small dark circle
        let iconContainer = NSView()
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        iconContainer.layer?.cornerRadius = 10
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconContainer)

        let icon = NSImageView()
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            icon.image = img.withSymbolConfiguration(cfg)
        }
        icon.contentTintColor = NSColor.controlAccentColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(icon)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(titleLabel)

        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = NSColor(white: 0.5, alpha: 1)
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.maximumNumberOfLines = 0
        descLabel.preferredMaxLayoutWidth = 260
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(descLabel)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            iconContainer.topAnchor.constraint(equalTo: row.topAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 32),
            iconContainer.heightAnchor.constraint(equalToConstant: 32),

            icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),

            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            descLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            descLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])

        return row
    }
}
