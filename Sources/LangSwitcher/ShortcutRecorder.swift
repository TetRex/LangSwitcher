import AppKit
import Carbon.HIToolbox

/// Captures a single shortcut from local key events and cleans up its monitor.
@MainActor
final class ShortcutRecorder {
    private var localMonitor: Any?
    private(set) var isRecording = false

    deinit {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    func start(onCancel: @escaping () -> Void,
               onShortcut: @escaping (_ keyCode: Int, _ modifiers: UInt64) -> Void) {
        stop()
        isRecording = true

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.isRecording = false

            if event.keyCode == UInt16(kVK_Escape),
               event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                self.stop()
                onCancel()
                return nil
            }

            let keyCode = Int(event.keyCode)
            let modifiers = ShortcutConfiguration.significantModifiers(UInt64(event.modifierFlags.rawValue))
            self.stop()
            onShortcut(keyCode, modifiers)
            return nil
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        isRecording = false
    }
}
