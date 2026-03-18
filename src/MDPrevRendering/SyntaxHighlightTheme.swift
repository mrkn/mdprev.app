import Foundation

public struct SyntaxHighlightTheme: Hashable, Codable, Sendable {
    public let rawValue: String

    public static let disabled = SyntaxHighlightTheme(rawValue: "disabled")
    public static let followPreview = SyntaxHighlightTheme(rawValue: "follow-preview")
    public static let github = SyntaxHighlightTheme(rawValue: "github")
    public static let githubDark = SyntaxHighlightTheme(rawValue: "github-dark")
    public static let atomOneDark = SyntaxHighlightTheme(rawValue: "atom-one-dark")
    public static let xcode = SyntaxHighlightTheme(rawValue: "xcode")

    public static let defaultTheme: SyntaxHighlightTheme = .followPreview

    public static var allCases: [SyntaxHighlightTheme] {
        [disabled, followPreview] + HighlightJSThemeCatalog.availableThemes.map { theme in
            SyntaxHighlightTheme(rawValue: theme.identifier)
        }
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(storedValue: String?) {
        guard let storedValue else {
            self = Self.defaultTheme
            return
        }

        self = Self.validated(rawValue: storedValue)
    }

    public var displayName: String {
        if self == .disabled {
            return "Disabled"
        }

        if self == .followPreview {
            return "Follow Preview"
        }

        return HighlightJSThemeCatalog.displayName(for: rawValue)
    }

    public var isDisabled: Bool {
        self == .disabled
    }

    public var isFollowPreview: Bool {
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
