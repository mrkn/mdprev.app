import AppKit

enum LinkOpenDisposition: Equatable {
    case currentTab
    case newTab
    case newWindow

    static func from(modifierFlags: NSEvent.ModifierFlags) -> LinkOpenDisposition {
        if modifierFlags.contains(.shift) {
            return .newWindow
        }

        if modifierFlags.contains(.command) {
            return .newTab
        }

        return .currentTab
    }
}
