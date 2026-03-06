import Combine
import Foundation

enum FollowThemeSepiaMode: String, CaseIterable, Codable {
    case sameAsLight = "same-as-light"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .sameAsLight:
            return "Use Light Theme"
        case .custom:
            return "Use Separate Theme"
        }
    }
}

@MainActor
final class SyntaxHighlightSettingsStore: ObservableObject {
    @Published private(set) var followThemeLightIdentifier: String
    @Published private(set) var followThemeDarkIdentifier: String
    @Published private(set) var followThemeSepiaMode: FollowThemeSepiaMode
    @Published private(set) var followThemeSepiaIdentifier: String

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let storedLight = userDefaults.string(forKey: Self.followThemeLightDefaultsKey)
        let storedDark = userDefaults.string(forKey: Self.followThemeDarkDefaultsKey)
        let storedSepia = userDefaults.string(forKey: Self.followThemeSepiaDefaultsKey)
        let storedSepiaMode = userDefaults.string(forKey: Self.followThemeSepiaModeDefaultsKey)

        let resolvedLight = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: storedLight ?? HighlightJSThemeCatalog.defaultFollowThemeLightIdentifier,
            fallback: HighlightJSThemeCatalog.defaultFollowThemeDarkIdentifier
        )
        let resolvedDark = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: storedDark ?? HighlightJSThemeCatalog.defaultFollowThemeDarkIdentifier,
            fallback: resolvedLight
        )
        let resolvedSepia = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: storedSepia ?? HighlightJSThemeCatalog.defaultFollowThemeSepiaIdentifier,
            fallback: resolvedLight
        )
        let resolvedSepiaMode = FollowThemeSepiaMode(rawValue: storedSepiaMode ?? "") ?? .sameAsLight

        followThemeLightIdentifier = resolvedLight
        followThemeDarkIdentifier = resolvedDark
        followThemeSepiaMode = resolvedSepiaMode
        followThemeSepiaIdentifier = resolvedSepia
    }

    var availableThemes: [HighlightJSThemeDefinition] {
        HighlightJSThemeCatalog.availableThemes
    }

    var effectiveFollowThemeSepiaIdentifier: String {
        switch followThemeSepiaMode {
        case .sameAsLight:
            return followThemeLightIdentifier
        case .custom:
            return followThemeSepiaIdentifier
        }
    }

    func setFollowThemeLightIdentifier(_ identifier: String) {
        let resolved = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: identifier,
            fallback: followThemeDarkIdentifier
        )

        guard resolved != followThemeLightIdentifier else {
            return
        }

        followThemeLightIdentifier = resolved
        userDefaults.set(resolved, forKey: Self.followThemeLightDefaultsKey)
    }

    func setFollowThemeDarkIdentifier(_ identifier: String) {
        let resolved = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: identifier,
            fallback: followThemeLightIdentifier
        )

        guard resolved != followThemeDarkIdentifier else {
            return
        }

        followThemeDarkIdentifier = resolved
        userDefaults.set(resolved, forKey: Self.followThemeDarkDefaultsKey)
    }

    func setFollowThemeSepiaMode(_ mode: FollowThemeSepiaMode) {
        guard mode != followThemeSepiaMode else {
            return
        }

        followThemeSepiaMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.followThemeSepiaModeDefaultsKey)
    }

    func setFollowThemeSepiaIdentifier(_ identifier: String) {
        let resolved = HighlightJSThemeCatalog.resolvedThemeIdentifier(
            primary: identifier,
            fallback: followThemeLightIdentifier
        )

        guard resolved != followThemeSepiaIdentifier else {
            return
        }

        followThemeSepiaIdentifier = resolved
        userDefaults.set(resolved, forKey: Self.followThemeSepiaDefaultsKey)
    }

    private static let followThemeLightDefaultsKey = "syntaxHighlight.followTheme.light"
    private static let followThemeDarkDefaultsKey = "syntaxHighlight.followTheme.dark"
    private static let followThemeSepiaModeDefaultsKey = "syntaxHighlight.followTheme.sepia.mode"
    private static let followThemeSepiaDefaultsKey = "syntaxHighlight.followTheme.sepia.theme"
}
