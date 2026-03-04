import Foundation

struct SyntaxHighlightTheme: Hashable, Codable {
    let rawValue: String

    static let disabled = SyntaxHighlightTheme(rawValue: "disabled")
    static let followPreview = SyntaxHighlightTheme(rawValue: "follow-preview")
    static let github = SyntaxHighlightTheme(rawValue: "github")
    static let githubDark = SyntaxHighlightTheme(rawValue: "github-dark")
    static let atomOneDark = SyntaxHighlightTheme(rawValue: "atom-one-dark")
    static let xcode = SyntaxHighlightTheme(rawValue: "xcode")

    static let defaultTheme: SyntaxHighlightTheme = .followPreview

    static var allCases: [SyntaxHighlightTheme] {
        [disabled, followPreview] + HighlightJSThemeCatalog.availableThemes.map { theme in
            SyntaxHighlightTheme(rawValue: theme.identifier)
        }
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(storedValue: String?) {
        guard let storedValue else {
            self = Self.defaultTheme
            return
        }

        self = Self.validated(rawValue: storedValue)
    }

    var displayName: String {
        if self == .disabled {
            return "Disabled"
        }

        if self == .followPreview {
            return "Follow Preview"
        }

        return HighlightJSThemeCatalog.displayName(for: rawValue)
    }

    var isDisabled: Bool {
        self == .disabled
    }

    var isFollowPreview: Bool {
        self == .followPreview
    }

    private static func validated(rawValue: String) -> SyntaxHighlightTheme {
        if rawValue == disabled.rawValue ||
            rawValue == followPreview.rawValue ||
            HighlightJSThemeCatalog.contains(identifier: rawValue) {
            return SyntaxHighlightTheme(rawValue: rawValue)
        }

        return .defaultTheme
    }
}
