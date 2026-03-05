import AppKit

/// A welcome window shown on first launch with usage instructions,
/// shortcut info, and accessibility permission guidance.
@MainActor
final class WelcomeWindowController: NSWindowController {

    private static let hasSeenWelcomeKey = "HasSeenWelcome"

    /// Returns `true` if the welcome window has already been shown once.
    static var hasSeenWelcome: Bool {
        UserDefaults.standard.bool(forKey: hasSeenWelcomeKey)
    }

    /// Callback fired when the user clicks "Grant Access".
    var onRequestAccessibility: (() -> Void)?

    // MARK: - Init

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to LangSwitch"
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

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        contentView.addSubview(scrollView)

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView

        // --- Buttons ---
        let grantButton = NSButton(title: "Grant Accessibility Access…",
                                   target: self,
                                   action: #selector(grantAccessibility))
        grantButton.bezelStyle = .rounded
        grantButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(grantButton)

        let closeButton = NSButton(title: "Get Started",
                                   target: self,
                                   action: #selector(dismissWelcome))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: grantButton.topAnchor, constant: -12),

            grantButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            grantButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])

        // --- Populate rich text ---
        textView.textStorage?.setAttributedString(buildAttributedContent())
    }

    // MARK: - Content

    private func buildAttributedContent() -> NSAttributedString {
        let result = NSMutableAttributedString()

        let titleFont = NSFont.systemFont(ofSize: 20, weight: .bold)
        let headingFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let bodyFont = NSFont.systemFont(ofSize: 13, weight: .regular)

        let titleColor = NSColor.labelColor
        let headingColor = NSColor.labelColor
        let bodyColor = NSColor.secondaryLabelColor

        func append(_ text: String, font: NSFont, color: NSColor, spacing: CGFloat = 4) {
            let para = NSMutableParagraphStyle()
            para.paragraphSpacing = spacing
            result.append(NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: para,
            ]))
        }

        // Title
        append("Welcome to LangSwitch ⌨️\n\n", font: titleFont, color: titleColor, spacing: 8)

        // --- What it does ---
        append("What does it do?\n", font: headingFont, color: headingColor, spacing: 6)
        append("""
        LangSwitch watches your keyboard input and automatically \
        fixes words you accidentally type in Russian (Cyrillic) layout \
        when you meant to type in English.\n\
        When you press Space or Enter and the typed word is Cyrillic but \
        not a valid Russian word — and the QWERTY equivalent is a valid \
        English word — it swaps the text and switches your layout to English.\n\n
        """, font: bodyFont, color: bodyColor)

        // --- How to use ---
        append("How to use\n", font: headingFont, color: headingColor, spacing: 6)
        append("""
        1. Just type normally. LangSwitch runs in the background.\n\
        2. If you type a word in the wrong layout and press Space / Enter,\n\
           it will be corrected automatically.\n\
        3. Use the menu bar icon (⌨) to enable / disable the app.\n\n
        """, font: bodyFont, color: bodyColor)

        // --- Force convert ---
        append("Force‑convert shortcut\n", font: headingFont, color: headingColor, spacing: 6)
        append("""
        You can also force‑convert the current word at any time using \
        a keyboard shortcut (default: ⌥T).\n\
        • With modifiers (e.g. ⌥T) — a single press converts the word.\n\
        • Without modifiers (e.g. just T) — double‑tap to convert.\n\n
        """, font: bodyFont, color: bodyColor)

        // --- Changing shortcut ---
        append("Changing the shortcut\n", font: headingFont, color: headingColor, spacing: 6)
        append("""
        1. Click the ⌨ icon in the menu bar.\n\
        2. Choose "Settings…" (or press ⌘,).\n\
        3. Click the shortcut field and press your new key combination.\n\
        4. Press Escape to cancel.\n\n
        """, font: bodyFont, color: bodyColor)

        // --- Permissions ---
        append("Accessibility Permission\n", font: headingFont, color: headingColor, spacing: 6)
        append("""
        LangSwitch needs Accessibility access to read and replace\n\
        keyboard input. Without it the app cannot function.\n\n\
        To grant access:\n\
        1. Open System Settings → Privacy & Security → Accessibility.\n\
        2. Enable the toggle next to LangSwitch.\n\
        3. If you don't see it, click "+" and add the app manually.\n\n\
        You can also use the button below to open the permission dialog.\n
        """, font: bodyFont, color: bodyColor)

        return result
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
        UserDefaults.standard.set(true, forKey: Self.hasSeenWelcomeKey)
        window?.close()
    }
}
