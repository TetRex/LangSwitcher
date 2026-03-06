import AppKit
import Carbon.HIToolbox

/// A settings window that lets the user configure the force‑convert shortcut.
/// Supports any key with optional modifiers (⌘, ⌥, ⌃, ⇧).
@MainActor
final class SettingsWindowController: NSWindowController {

    // MARK: - Defaults keys

    private static let shortcutKeyCodeKey   = "ForceConvertKeyCode"
    private static let shortcutModifiersKey = "ForceConvertModifiers"

    // MARK: - UI

    private let shortcutField = NSTextField()
    private let instructionLabel = NSTextField(labelWithString: "")
    private let modeLabel = NSTextField(labelWithString: "")
    private var isRecording = false
    private var localMonitor: Any?

    /// Called when the user picks a new shortcut.
    var onShortcutChanged: ((_ keyCode: Int, _ modifiers: UInt64) -> Void)?

    // MARK: - Current value

    private var currentKeyCode: Int
    private var currentModifiers: UInt64   // raw CGEventFlags bits for ⌘⌥⌃⇧

    // MARK: - Init

    init(currentKeyCode: Int, currentModifiers: UInt64) {
        self.currentKeyCode = currentKeyCode
        self.currentModifiers = currentModifiers

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LangSwitcher Settings"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildUI()
        updateFieldDisplay()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI construction

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let titleLabel = NSTextField(labelWithString: "Force‑convert shortcut:")
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        shortcutField.isEditable = false
        shortcutField.isSelectable = false
        shortcutField.alignment = .center
        shortcutField.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        shortcutField.isBezeled = true
        shortcutField.bezelStyle = .roundedBezel
        shortcutField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shortcutField)

        let click = NSClickGestureRecognizer(target: self, action: #selector(startRecording))
        shortcutField.addGestureRecognizer(click)

        instructionLabel.font = .systemFont(ofSize: 11)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(instructionLabel)

        modeLabel.font = .systemFont(ofSize: 11)
        modeLabel.textColor = .tertiaryLabelColor
        modeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(modeLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            shortcutField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            shortcutField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            shortcutField.widthAnchor.constraint(equalToConstant: 220),
            shortcutField.heightAnchor.constraint(equalToConstant: 28),

            instructionLabel.topAnchor.constraint(equalTo: shortcutField.bottomAnchor, constant: 8),
            instructionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            modeLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 4),
            modeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            modeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Display

    private func updateFieldDisplay() {
        shortcutField.stringValue = Self.displayName(keyCode: currentKeyCode,
                                                      modifiers: currentModifiers)
        instructionLabel.stringValue = "Click the field, then press your shortcut."

        let hasModifiers = Self.significantModifiers(currentModifiers) != 0
        modeLabel.stringValue = hasModifiers
            ? "Mode: single press"
            : "Mode: double‑tap"
    }

    // MARK: - Recording

    @objc private func startRecording() {
        isRecording = true
        shortcutField.stringValue = "Press shortcut…"
        instructionLabel.stringValue = "Press Escape to cancel. Hold modifiers + key."

        // Remove any prior monitor
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.isRecording = false

            if event.keyCode == UInt16(kVK_Escape),
               event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                self.updateFieldDisplay()
                if let m = self.localMonitor { NSEvent.removeMonitor(m); self.localMonitor = nil }
                return nil
            }

            let keyCode = Int(event.keyCode)
            let mods = Self.significantModifiers(UInt64(event.modifierFlags.rawValue))
            self.currentKeyCode = keyCode
            self.currentModifiers = mods
            self.updateFieldDisplay()

            // Persist
            UserDefaults.standard.set(keyCode, forKey: Self.shortcutKeyCodeKey)
            UserDefaults.standard.set(Int64(bitPattern: mods), forKey: Self.shortcutModifiersKey)

            self.onShortcutChanged?(keyCode, mods)

            if let m = self.localMonitor { NSEvent.removeMonitor(m); self.localMonitor = nil }
            return nil
        }
    }

    // MARK: - Persistence helpers

    static func savedKeyCode() -> Int {
        let val = UserDefaults.standard.integer(forKey: shortcutKeyCodeKey)
        return val == 0 ? kVK_ANSI_T : val
    }

    static func savedModifiers() -> UInt64 {
        if let val = UserDefaults.standard.object(forKey: shortcutModifiersKey) as? Int64 {
            return UInt64(bitPattern: val)
        }
        if let val = UserDefaults.standard.object(forKey: shortcutModifiersKey) as? Int {
            return UInt64(val)
        }
        return CGEventFlags.maskAlternate.rawValue   // default: ⌥
    }

    // MARK: - Modifier helpers

    /// Keeps only ⌘ ⌥ ⌃ ⇧ bits.
    static func significantModifiers(_ raw: UInt64) -> UInt64 {
        let mask: UInt64 = CGEventFlags.maskCommand.rawValue
                       | CGEventFlags.maskAlternate.rawValue
                       | CGEventFlags.maskControl.rawValue
                       | CGEventFlags.maskShift.rawValue
        return raw & mask
    }

    /// Human‑readable name like "⌥T" or "⌘⇧K" or "Tab (×2)".
    static func displayName(keyCode: Int, modifiers: UInt64) -> String {
        var parts: [String] = []
        if modifiers & CGEventFlags.maskControl.rawValue  != 0 { parts.append("⌃") }
        if modifiers & CGEventFlags.maskAlternate.rawValue != 0 { parts.append("⌥") }
        if modifiers & CGEventFlags.maskShift.rawValue     != 0 { parts.append("⇧") }
        if modifiers & CGEventFlags.maskCommand.rawValue   != 0 { parts.append("⌘") }

        let keyName = nameForKeyCode(keyCode)

        if parts.isEmpty {
            return "\(keyName) (×2)"
        }
        return parts.joined() + keyName
    }

    // MARK: - Key name mapping

    private static let keyNames: [Int: String] = [
        kVK_Tab: "Tab",
        kVK_Return: "Return",
        kVK_Space: "Space",
        kVK_Delete: "Delete",
        kVK_ForwardDelete: "Fwd Delete",
        kVK_Escape: "Escape",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_CapsLock: "Caps Lock",
        kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "Home", kVK_End: "End",
        kVK_PageUp: "Page Up", kVK_PageDown: "Page Down",
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C",
        kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
        kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I",
        kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
        kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
        kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U",
        kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2",
        kVK_ANSI_3: "3", kVK_ANSI_4: "4", kVK_ANSI_5: "5",
        kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8",
        kVK_ANSI_9: "9",
        kVK_ANSI_Grave: "`",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=",
        kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Comma: ",",
        kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
    ]

    static func nameForKeyCode(_ keyCode: Int) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }
}
