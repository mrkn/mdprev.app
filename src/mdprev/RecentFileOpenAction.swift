import AppKit

enum RecentFileOpenAction: Equatable {
    case openInFocusedWindow
    case openInNewWindow

    static func from(modifierFlags: NSEvent.ModifierFlags, hasFocusedModel: Bool) -> RecentFileOpenAction {
        if modifierFlags.contains(.option) {
            return .openInNewWindow
        }

        if hasFocusedModel {
            return .openInFocusedWindow
        }

        return .openInNewWindow
    }
}
