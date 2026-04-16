import AppKit
import Carbon.HIToolbox

/// Shared storage and display helpers for the force-convert shortcut.
enum ShortcutConfiguration {
    private static let shortcutKeyCodeKey = "ForceConvertKeyCode"
    private static let shortcutModifiersKey = "ForceConvertModifiers"

    static func savedKeyCode() -> Int {
        let value = UserDefaults.standard.integer(forKey: shortcutKeyCodeKey)
        return value == 0 ? kVK_ANSI_T : value
    }

    static func savedModifiers() -> UInt64 {
        if let value = UserDefaults.standard.object(forKey: shortcutModifiersKey) as? Int64 {
            return UInt64(bitPattern: value)
        }
        if let value = UserDefaults.standard.object(forKey: shortcutModifiersKey) as? Int {
            return UInt64(value)
        }
        return CGEventFlags.maskAlternate.rawValue
    }

    static func save(keyCode: Int, modifiers: UInt64) {
        UserDefaults.standard.set(keyCode, forKey: shortcutKeyCodeKey)
        UserDefaults.standard.set(Int64(bitPattern: modifiers), forKey: shortcutModifiersKey)
    }

    /// Keeps only ⌘ ⌥ ⌃ ⇧ bits.
    static func significantModifiers(_ raw: UInt64) -> UInt64 {
        let mask: UInt64 = CGEventFlags.maskCommand.rawValue
            | CGEventFlags.maskAlternate.rawValue
            | CGEventFlags.maskControl.rawValue
            | CGEventFlags.maskShift.rawValue
        return raw & mask
    }

    /// Human-readable name like "⌥T" or "⌘⇧K" or "Tab (×2)".
    static func displayName(keyCode: Int, modifiers: UInt64) -> String {
        var parts: [String] = []
        if modifiers & CGEventFlags.maskControl.rawValue != 0 { parts.append("⌃") }
        if modifiers & CGEventFlags.maskAlternate.rawValue != 0 { parts.append("⌥") }
        if modifiers & CGEventFlags.maskShift.rawValue != 0 { parts.append("⇧") }
        if modifiers & CGEventFlags.maskCommand.rawValue != 0 { parts.append("⌘") }

        let keyName = nameForKeyCode(keyCode)
        return parts.isEmpty ? "\(keyName) (×2)" : parts.joined() + keyName
    }

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

    private static func nameForKeyCode(_ keyCode: Int) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }
}
