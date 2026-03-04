import AppKit
import Foundation

@MainActor
final class KeyboardShortcutService {
    private weak var window: NSWindow?
    private var keyboardMonitor: Any?
    private var onSelectAll: (() -> Void)?

    func attach(to window: NSWindow, onSelectAll: @escaping () -> Void) {
        self.window = window
        self.onSelectAll = onSelectAll

        guard keyboardMonitor == nil else {
            return
        }

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }
            guard self.window?.isKeyWindow == true else {
                return event
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.command], event.charactersIgnoringModifiers?.lowercased() == "a" {
                self.onSelectAll?()
                return nil
            }

            return event
        }
    }

    func detach() {
        guard let keyboardMonitor else {
            return
        }

        NSEvent.removeMonitor(keyboardMonitor)
        self.keyboardMonitor = nil
        onSelectAll = nil
    }
}
