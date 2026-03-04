import AppKit
import Foundation

@MainActor
final class KeyboardShortcutService {
    private weak var window: NSWindow?
    private var keyboardMonitor: Any?
    private var suppressCommandReleaseAfterSelectAll = false
    private var onSelectAll: (() -> Void)?

    func attach(to window: NSWindow, onSelectAll: @escaping () -> Void) {
        self.window = window
        self.onSelectAll = onSelectAll

        guard keyboardMonitor == nil else {
            return
        }

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else {
                return event
            }
            guard self.window?.isKeyWindow == true else {
                return event
            }

            switch event.type {
            case .keyDown:
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if flags == [.command], event.charactersIgnoringModifiers?.lowercased() == "a" {
                    self.onSelectAll?()
                    self.suppressCommandReleaseAfterSelectAll = true
                    return nil
                }

            case .flagsChanged:
                if self.suppressCommandReleaseAfterSelectAll,
                   !event.modifierFlags.contains(.command) {
                    self.suppressCommandReleaseAfterSelectAll = false
                    return nil
                }

            default:
                break
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
        suppressCommandReleaseAfterSelectAll = false
        onSelectAll = nil
    }
}
