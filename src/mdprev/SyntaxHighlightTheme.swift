import Foundation

enum SyntaxHighlightTheme: String, CaseIterable, Codable {
    case followPreview
    case github
    case githubDark
    case atomOneDark
    case xcode

    static let defaultTheme: SyntaxHighlightTheme = .followPreview

    init(storedValue: String?) {
        if let storedValue, let theme = Self(rawValue: storedValue) {
            self = theme
        } else {
            self = Self.defaultTheme
        }
    }

    var displayName: String {
        switch self {
        case .followPreview:
            return "Follow Preview"
        case .github:
            return "GitHub"
        case .githubDark:
            return "GitHub Dark"
        case .atomOneDark:
            return "Atom One Dark"
        case .xcode:
            return "Xcode"
        }
    }
}
