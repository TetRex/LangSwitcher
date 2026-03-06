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
    private static let maxWordLength = 80       // cap buffer to prevent unbounded growth
    private var lastShortcutTime: CFAbsoluteTime = 0  // for double‑tap mode
    private let doubleTapInterval: CFAbsoluteTime = 0.4
    var isEnabled: Bool = true
    /// Virtual key code for the force‑convert shortcut.
    var forceConvertKeyCode: Int
    /// Modifier flags (⌘⌥⌃⇧) for the shortcut. 0 = double‑tap mode.
    var forceConvertModifiers: UInt64

    // MARK: - Lifecycle

    init() {
        forceConvertKeyCode = SettingsWindowController.savedKeyCode()
        forceConvertModifiers = SettingsWindowController.savedModifiers()
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

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let eventMods = SettingsWindowController.significantModifiers(UInt64(event.flags.rawValue))

        // Check for the force‑convert shortcut FIRST (works with modifiers).
        if keyCode == Int64(forceConvertKeyCode) {
            let requiredMods = forceConvertModifiers
            let hasModifiers = requiredMods != 0

            if hasModifiers {
                // Modifier‑based shortcut: single press triggers immediately.
                if eventMods == requiredMods {
                    let word = currentWord
                    currentWord = ""
                    if CyrillicMapper.isCyrillic(word),
                       let english = CyrillicMapper.convert(word) {
                        replaceCurrentWord(charCount: word.count,
                                           replacement: english)
                        switchToEnglishLayout()
                    }
                    return nil
                }
                // Modifiers don't match — fall through to normal handling.
            } else {
                // No‑modifier shortcut: double‑tap mode.
                if eventMods == 0 {
                    let now = CFAbsoluteTimeGetCurrent()
                    if now - lastShortcutTime <= doubleTapInterval {
                        lastShortcutTime = 0
                        let word = currentWord
                        currentWord = ""
                        if CyrillicMapper.isCyrillic(word),
                           let english = CyrillicMapper.convert(word) {
                            replaceCurrentWord(charCount: word.count,
                                               replacement: english)
                            switchToEnglishLayout()
                        }
                        return nil
                    } else {
                        lastShortcutTime = now
                        return Unmanaged.passUnretained(event)
                    }
                }
            }
        }

        // Let other modifier combos (Cmd+C, etc.) pass through untouched.
        if eventMods != 0 {
            return Unmanaged.passUnretained(event)
        }

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
               !CyrillicMapper.isValidRussianWord(word),
               let english = CyrillicMapper.convert(word),
               CyrillicMapper.isValidEnglishWord(english) {
                replaceLastWord(charCount: word.count,
                                replacement: english,
                                trailingEvent: event)
                switchToEnglishLayout()
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        // Escape, arrow keys, etc. — reset buffer and pass through
        if isNonCharacterKey(keyCode) {
            currentWord = ""
            return Unmanaged.passUnretained(event)
        }

        // Ordinary character — append to buffer (capped to limit memory)
        if !chars.isEmpty {
            if currentWord.count < Self.maxWordLength {
                currentWord.append(chars)
            } else {
                // Word is unreasonably long — reset to avoid unbounded growth.
                currentWord = String(chars)
            }
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Replace typed word

    /// Selects the Cyrillic word, then types the full replacement + trailing
    /// character as a single Unicode event — effectively an atomic swap that
    /// appears instant to the user.
    private func replaceLastWord(charCount: Int,
                                  replacement: String,
                                  trailingEvent: CGEvent) {

        // Disable the tap so our synthetic events don't re‑enter handleKeyDown.
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        let src = CGEventSource(stateID: .combinedSessionState)

        // 1. Select the Cyrillic word: Shift + Left Arrow × charCount.
        for _ in 0..<charCount {
            postKey(CGKeyCode(kVK_LeftArrow), flags: .maskShift, source: src)
        }

        // 2. Type the full replacement + trailing Space/Enter as ONE event.
        let trailingKeyCode = trailingEvent.getIntegerValueField(.keyboardEventKeycode)
        let trailing: String = trailingKeyCode == Int64(kVK_Return) ? "\n" : " "
        typeUnicodeString(replacement + trailing, source: src)

        // 3. Re‑enable the tap.
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    /// Selects `charCount` characters and replaces them with `replacement`
    /// without appending a trailing character. Used by the double‑Tab trigger.
    private func replaceCurrentWord(charCount: Int,
                                     replacement: String) {

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        let src = CGEventSource(stateID: .combinedSessionState)

        // Also select the first Tab that was let through, so +1.
        for _ in 0..<(charCount + 1) {
            postKey(CGKeyCode(kVK_LeftArrow), flags: .maskShift, source: src)
        }

        typeUnicodeString(replacement, source: src)

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    /// Posts a single Unicode string as one keyboard event pair (down + up).
    private func typeUnicodeString(_ text: String, source: CGEventSource?) {
        let utf16 = Array(text.utf16)
        if let down = CGEvent(keyboardEventSource: source,
                               virtualKey: 0, keyDown: true),
           let up = CGEvent(keyboardEventSource: source,
                             virtualKey: 0, keyDown: false) {
            down.keyboardSetUnicodeString(stringLength: utf16.count,
                                          unicodeString: utf16)
            up.keyboardSetUnicodeString(stringLength: utf16.count,
                                        unicodeString: utf16)
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
        }
    }

    /// Posts a single key press (down + up) with the given modifier flags.
    private func postKey(_ keyCode: CGKeyCode,
                          flags: CGEventFlags,
                          source: CGEventSource?) {
        if let down = CGEvent(keyboardEventSource: source,
                               virtualKey: keyCode, keyDown: true),
           let up = CGEvent(keyboardEventSource: source,
                             virtualKey: keyCode, keyDown: false) {
            down.flags = flags
            up.flags = flags
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - Helpers

    /// Criteria dictionary for finding keyboard input sources (allocated once).
    private static let inputSourceCriteria: CFDictionary = [
        kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
        kTISPropertyInputSourceIsEnabled: kCFBooleanTrue!,
        kTISPropertyInputSourceIsSelectCapable: kCFBooleanTrue!,
    ] as CFDictionary

    /// Switches the active keyboard layout to the first English (ABC/US) input source.
    private func switchToEnglishLayout() {
        guard let sources = TISCreateInputSourceList(Self.inputSourceCriteria, false)?
                .takeRetainedValue() as? [TISInputSource] else { return }

        for source in sources {
            guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
                continue
            }
            let sourceID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            // Match common English layouts: US, ABC, British, etc.
            if sourceID.contains("com.apple.keylayout.US")
                || sourceID.contains("com.apple.keylayout.ABC")
                || sourceID.contains("com.apple.keylayout.British") {
                TISSelectInputSource(source)
                return
            }
        }
    }

    /// Key codes that don't produce printable characters (allocated once).
    private static let nonCharKeys: Set<Int> = [
        kVK_Escape,
        kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow,
        kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown,
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
        kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
        kVK_ForwardDelete,
        kVK_Command, kVK_Shift, kVK_Option, kVK_Control,
        kVK_RightCommand, kVK_RightShift, kVK_RightOption, kVK_RightControl,
        kVK_CapsLock, kVK_Function,
    ]

    /// Returns `true` for key codes that don't produce printable characters.
    private func isNonCharacterKey(_ keyCode: Int64) -> Bool {
        Self.nonCharKeys.contains(Int(keyCode))
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
                LangSwitcher needs Accessibility access to intercept keyboard input.
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
