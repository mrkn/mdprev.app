import Foundation

public enum SharedPreviewSettings {
    public static let defaultsSuiteName = "io.github.mrkn.mdprev.shared"

    public static let baseFontSizeDefaultsKey = "preview.baseFontSize"
    public static let previewThemeDefaultsKey = "preview.theme"
    public static let syntaxThemeDefaultsKey = "preview.syntaxTheme"
    public static let followThemeLightDefaultsKey = "syntaxHighlight.followTheme.light"
    public static let followThemeDarkDefaultsKey = "syntaxHighlight.followTheme.dark"
    public static let followThemeSepiaModeDefaultsKey = "syntaxHighlight.followTheme.sepia.mode"
    public static let followThemeSepiaDefaultsKey = "syntaxHighlight.followTheme.sepia.theme"
    public static let migrationCompletedDefaultsKey = "sharedPreviewSettingsMigrationCompleted"

    public static func userDefaults(migrateLegacySettings: Bool = true) -> UserDefaults {
        let sharedDefaults = UserDefaults(suiteName: defaultsSuiteName) ?? .standard
        if migrateLegacySettings {
            migrateLegacySettingsIfNeeded(to: sharedDefaults)
        }
        return sharedDefaults
    }

    public static func currentValues(userDefaults: UserDefaults = userDefaults()) -> Values {
        let baseFontSize: Double
        if let storedValue = userDefaults.object(forKey: baseFontSizeDefaultsKey) as? NSNumber {
            baseFontSize = min(max(storedValue.doubleValue, MarkdownRenderer.defaultBaseFontSizeRange.lowerBound),
                               MarkdownRenderer.defaultBaseFontSizeRange.upperBound)
        } else {
            baseFontSize = MarkdownRenderer.defaultBaseFontSize
        }

        let previewTheme = PreviewTheme(
            storedValue: userDefaults.string(forKey: previewThemeDefaultsKey)
        )
        let syntaxTheme = SyntaxHighlightTheme(
            storedValue: userDefaults.string(forKey: syntaxThemeDefaultsKey)
        )
        let followThemeLightIdentifier = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: userDefaults.string(forKey: followThemeLightDefaultsKey)
                ?? HighlightJSThemeCatalog.defaultFollowThemeLightIdentifier,
            fallback: HighlightJSThemeCatalog.defaultFollowThemeDarkIdentifier
        )
        let followThemeDarkIdentifier = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: userDefaults.string(forKey: followThemeDarkDefaultsKey)
                ?? HighlightJSThemeCatalog.defaultFollowThemeDarkIdentifier,
            fallback: followThemeLightIdentifier
        )
        let followThemeSepiaMode = FollowThemeSepiaMode(
            rawValue: userDefaults.string(forKey: followThemeSepiaModeDefaultsKey) ?? ""
        ) ?? .sameAsLight
        let storedSepiaIdentifier = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: userDefaults.string(forKey: followThemeSepiaDefaultsKey)
                ?? HighlightJSThemeCatalog.defaultFollowThemeSepiaIdentifier,
            fallback: followThemeLightIdentifier
        )
        let followThemeSepiaIdentifier: String
        switch followThemeSepiaMode {
        case .sameAsLight:
            followThemeSepiaIdentifier = followThemeLightIdentifier
        case .custom:
            followThemeSepiaIdentifier = storedSepiaIdentifier
        }

        return Values(
            baseFontSize: baseFontSize,
            previewTheme: previewTheme,
            syntaxHighlightTheme: syntaxTheme,
            followThemeLightIdentifier: followThemeLightIdentifier,
            followThemeDarkIdentifier: followThemeDarkIdentifier,
            followThemeSepiaIdentifier: followThemeSepiaIdentifier
        )
    }

    public struct Values: Sendable, Equatable {
        public let baseFontSize: Double
        public let previewTheme: PreviewTheme
        public let syntaxHighlightTheme: SyntaxHighlightTheme
        public let followThemeLightIdentifier: String
        public let followThemeDarkIdentifier: String
        public let followThemeSepiaIdentifier: String

        public init(
            baseFontSize: Double,
            previewTheme: PreviewTheme,
            syntaxHighlightTheme: SyntaxHighlightTheme,
            followThemeLightIdentifier: String,
            followThemeDarkIdentifier: String,
            followThemeSepiaIdentifier: String
        ) {
            self.baseFontSize = baseFontSize
            self.previewTheme = previewTheme
            self.syntaxHighlightTheme = syntaxHighlightTheme
            self.followThemeLightIdentifier = followThemeLightIdentifier
            self.followThemeDarkIdentifier = followThemeDarkIdentifier
            self.followThemeSepiaIdentifier = followThemeSepiaIdentifier
        }
    }

    static func migrateLegacySettingsIfNeeded(
        to sharedDefaults: UserDefaults,
        legacyDefaults: UserDefaults = .standard
    ) {
        let keys = [
            baseFontSizeDefaultsKey,
            previewThemeDefaultsKey,
            syntaxThemeDefaultsKey,
            followThemeLightDefaultsKey,
            followThemeDarkDefaultsKey,
            followThemeSepiaModeDefaultsKey,
            followThemeSepiaDefaultsKey
        ]

        var copiedAnyValue = false
        for key in keys where sharedDefaults.object(forKey: key) == nil {
            guard let value = legacyDefaults.object(forKey: key) else {
                continue
            }

            sharedDefaults.set(value, forKey: key)
            copiedAnyValue = true
        }

        if copiedAnyValue || !sharedDefaults.bool(forKey: migrationCompletedDefaultsKey) {
            sharedDefaults.set(true, forKey: migrationCompletedDefaultsKey)
        }
    }
}

public enum FollowThemeSepiaMode: String, CaseIterable, Codable, Sendable {
    case sameAsLight = "same-as-light"
    case custom = "custom"
}
