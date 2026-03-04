import AppKit
import Carbon.HIToolbox

/// A settings window that lets the user configure the force‑convert shortcut.
@MainActor
final class SettingsWindowController: NSWindowController {

    // MARK: - Defaults keys

    private static let shortcutKeyCodeKey = "ForceConvertKeyCode"
    private static let shortcutKeyNameKey = "ForceConvertKeyName"

    // MARK: - UI

    private let shortcutField = NSTextField()
    private let instructionLabel = NSTextField(labelWithString: "")
    private var isRecording = false

    /// Called when the user picks a new shortcut key.
    var onShortcutChanged: ((_ keyCode: Int, _ keyName: String) -> Void)?

    // MARK: - Current value

    private var currentKeyCode: Int
    private var currentKeyName: String

    // MARK: - Init

    init(currentKeyCode: Int, currentKeyName: String) {
        self.currentKeyCode = currentKeyCode
        self.currentKeyName = currentKeyName

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LangSwitch Settings"
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

        let titleLabel = NSTextField(labelWithString: "Force‑convert shortcut (double‑tap):")
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

        // Click on the field starts recording
        let click = NSClickGestureRecognizer(target: self, action: #selector(startRecording))
        shortcutField.addGestureRecognizer(click)

        instructionLabel.font = .systemFont(ofSize: 11)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(instructionLabel)

        let resetButton = NSButton(title: "Reset to Tab", target: self, action: #selector(resetToDefault))
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(resetButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            shortcutField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            shortcutField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            shortcutField.widthAnchor.constraint(equalToConstant: 200),
            shortcutField.heightAnchor.constraint(equalToConstant: 28),

            resetButton.centerYAnchor.constraint(equalTo: shortcutField.centerYAnchor),
            resetButton.leadingAnchor.constraint(equalTo: shortcutField.trailingAnchor, constant: 12),
            resetButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),

            instructionLabel.topAnchor.constraint(equalTo: shortcutField.bottomAnchor, constant: 8),
            instructionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Display

    private func updateFieldDisplay() {
        shortcutField.stringValue = currentKeyName
        instructionLabel.stringValue = "Click the field, then press a key to set a new shortcut."
    }

    // MARK: - Recording

    @objc private func startRecording() {
        isRecording = true
        shortcutField.stringValue = "Press a key…"
        instructionLabel.stringValue = "Press Escape to cancel."
        // Use a local event monitor to capture the next key press.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.isRecording = false

            if event.keyCode == UInt16(kVK_Escape) {
                // Cancel — restore display
                self.updateFieldDisplay()
                return nil
            }

            let keyCode = Int(event.keyCode)
            let keyName = Self.nameForKeyCode(keyCode)
            self.currentKeyCode = keyCode
            self.currentKeyName = keyName
            self.updateFieldDisplay()

            // Persist
            UserDefaults.standard.set(keyCode, forKey: Self.shortcutKeyCodeKey)
            UserDefaults.standard.set(keyName, forKey: Self.shortcutKeyNameKey)

            self.onShortcutChanged?(keyCode, keyName)
            return nil  // eat the event
        }
    }

    @objc private func resetToDefault() {
        let keyCode = kVK_Tab
        let keyName = "Tab"
        currentKeyCode = keyCode
        currentKeyName = keyName
        updateFieldDisplay()

        UserDefaults.standard.set(keyCode, forKey: Self.shortcutKeyCodeKey)
        UserDefaults.standard.set(keyName, forKey: Self.shortcutKeyNameKey)

        onShortcutChanged?(keyCode, keyName)
    }

    // MARK: - Persistence helpers

    /// Loads the saved shortcut key code, defaulting to Tab.
    static func savedKeyCode() -> Int {
        let val = UserDefaults.standard.integer(forKey: shortcutKeyCodeKey)
        return val == 0 ? kVK_Tab : val
    }

    /// Loads the saved shortcut key name, defaulting to "Tab".
    static func savedKeyName() -> String {
        let val = UserDefaults.standard.string(forKey: shortcutKeyNameKey)
        return val ?? "Tab"
    }

    // MARK: - Key name mapping

    static func nameForKeyCode(_ keyCode: Int) -> String {
        let names: [Int: String] = [
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
        return names[keyCode] ?? "Key \(keyCode)"
    }
}
