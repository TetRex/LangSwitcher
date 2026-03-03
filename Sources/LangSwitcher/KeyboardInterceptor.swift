@preconcurrency import AppKit
import Carbon.HIToolbox

/// Intercepts global keyboard events via a CGEventTap,
/// buffers Cyrillic characters, and replaces them with English on Space / Enter.
@MainActor
final class KeyboardInterceptor {

    // MARK: - Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var currentWord: String = ""       // characters of the word in‑progress
    private var isSynthesizing: Bool = false   // true while we post replacement events
    var isEnabled: Bool = true

    // MARK: - Lifecycle

    init() {
        startEventTap()
    }

    // No deinit needed – this object lives for the entire app lifetime.
    // Cleanup happens automatically when the process exits.

    // MARK: - Event tap

    func startEventTap() {
        guard eventTap == nil else { return }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Because CGEventTapCallback is a C function pointer we cannot capture
        // `self` directly. We pass it via the `userInfo` pointer instead.
        let unmanagedSelf = Unmanaged.passUnretained(self)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: KeyboardInterceptor.tapCallback,
            userInfo: unmanagedSelf.toOpaque()
        ) else {
            print("⚠️  Could not create event tap – Accessibility permission required.")
            promptAccessibility()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("✅  Event tap started.")
    }

    func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - C callback → Swift

    private static let tapCallback: CGEventTapCallBack = {
        proxy, type, event, userInfo in

        // If the tap is disabled by the system, re‑enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let userInfo {
                let this = Unmanaged<KeyboardInterceptor>.fromOpaque(userInfo)
                    .takeUnretainedValue()
                if let tap = this.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown, let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let interceptor = Unmanaged<KeyboardInterceptor>.fromOpaque(userInfo)
            .takeUnretainedValue()

        return interceptor.handleKeyDown(event: event, proxy: proxy)
    }

    // MARK: - Key handling

    private func handleKeyDown(event: CGEvent,
                                proxy: CGEventTapProxy) -> Unmanaged<CGEvent>? {
        guard isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        // Ignore events we posted ourselves (backspaces + replacement chars).
        if isSynthesizing {
            return Unmanaged.passUnretained(event)
        }

        // Let system shortcuts through untouched (Cmd, Ctrl, Option combos).
        let modifiers = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate])
        if !modifiers.isEmpty {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let nsEvent = NSEvent(cgEvent: event)
        let chars = nsEvent?.characters ?? ""

        // Backspace — trim the current word buffer
        if keyCode == kVK_Delete {
            if !currentWord.isEmpty {
                currentWord.removeLast()
            }
            return Unmanaged.passUnretained(event)
        }

        // Space or Enter — check and potentially replace
        if keyCode == kVK_Space || keyCode == kVK_Return {
            let word = currentWord
            currentWord = ""
            if CyrillicMapper.isCyrillic(word),
               let english = CyrillicMapper.convert(word) {
                // Suppress the original Space/Enter so it doesn't arrive
                // before our backspaces. We re‑post it after the replacement.
                replaceLastWord(charCount: word.count,
                                replacement: english,
                                trailingEvent: event)
                return nil   // eat the original event
            }
            return Unmanaged.passUnretained(event)
        }

        // Escape, Tab, arrow keys, etc. — reset buffer and pass through
        if isNonCharacterKey(keyCode) {
            currentWord = ""
            return Unmanaged.passUnretained(event)
        }

        // Ordinary character — append to buffer
        if !chars.isEmpty {
            currentWord.append(chars)
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Replace typed word

    /// Deletes `charCount` characters backwards, types `replacement`,
    /// then re‑posts the trailing Space / Enter event.
    private func replaceLastWord(charCount: Int,
                                  replacement: String,
                                  trailingEvent: CGEvent) {

        isSynthesizing = true
        let src = CGEventSource(stateID: .combinedSessionState)

        // 1. Send Backspace × charCount to erase the Cyrillic word.
        for _ in 0..<charCount {
            if let down = CGEvent(keyboardEventSource: src,
                                   virtualKey: CGKeyCode(kVK_Delete),
                                   keyDown: true),
               let up = CGEvent(keyboardEventSource: src,
                                 virtualKey: CGKeyCode(kVK_Delete),
                                 keyDown: false) {
                down.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)
            }
        }

        // 2. Type the English replacement using Unicode key events.
        for ch in replacement {
            typeCharacter(ch, source: src)
        }

        // 3. Re‑post the original Space / Enter after the replacement.
        trailingEvent.post(tap: .cgSessionEventTap)

        isSynthesizing = false
    }

    /// Posts a keyboard event for a single Unicode character.
    private func typeCharacter(_ ch: Character, source: CGEventSource?) {
        let utf16 = Array(String(ch).utf16)
        if let down = CGEvent(keyboardEventSource: source,
                               virtualKey: 0,
                               keyDown: true),
           let up = CGEvent(keyboardEventSource: source,
                             virtualKey: 0,
                             keyDown: false) {
            down.keyboardSetUnicodeString(stringLength: utf16.count,
                                          unicodeString: utf16)
            up.keyboardSetUnicodeString(stringLength: utf16.count,
                                        unicodeString: utf16)
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - Helpers

    /// Returns `true` for key codes that don't produce printable characters.
    private func isNonCharacterKey(_ keyCode: Int64) -> Bool {
        let nonChar: Set<Int> = [
            kVK_Escape, kVK_Tab,
            kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow,
            kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown,
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
            kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
            kVK_ForwardDelete,
            kVK_Command, kVK_Shift, kVK_Option, kVK_Control,
            kVK_RightCommand, kVK_RightShift, kVK_RightOption, kVK_RightControl,
            kVK_CapsLock, kVK_Function,
        ]
        return nonChar.contains(Int(keyCode))
    }

    // MARK: - Accessibility prompt

    private func promptAccessibility() {
        // "AXTrustedCheckOptionPrompt" is the value of kAXTrustedCheckOptionPrompt.
        // We use the string literal to avoid Swift 6 concurrency errors on the C global.
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: kCFBooleanTrue!] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        if !trusted {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
                LangSwitch needs Accessibility access to intercept keyboard input.
                Please grant access in System Settings → Privacy & Security → Accessibility, \
                then relaunch the app.
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Quit")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            NSApp.terminate(nil)
        }
    }
}
