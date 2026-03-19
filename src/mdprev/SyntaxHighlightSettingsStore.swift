import Combine
import Foundation
import MDPrevRendering

extension FollowThemeSepiaMode {
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

    init(userDefaults: UserDefaults = SharedPreviewSettings.userDefaults()) {
        self.userDefaults = userDefaults

        let storedLight = userDefaults.string(forKey: SharedPreviewSettings.followThemeLightDefaultsKey)
        let storedDark = userDefaults.string(forKey: SharedPreviewSettings.followThemeDarkDefaultsKey)
        let storedSepia = userDefaults.string(forKey: SharedPreviewSettings.followThemeSepiaDefaultsKey)
        let storedSepiaMode = userDefaults.string(forKey: SharedPreviewSettings.followThemeSepiaModeDefaultsKey)

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
        userDefaults.set(resolved, forKey: SharedPreviewSettings.followThemeLightDefaultsKey)
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
        userDefaults.set(resolved, forKey: SharedPreviewSettings.followThemeDarkDefaultsKey)
    }

    func setFollowThemeSepiaMode(_ mode: FollowThemeSepiaMode) {
        guard mode != followThemeSepiaMode else {
            return
        }

        followThemeSepiaMode = mode
        userDefaults.set(mode.rawValue, forKey: SharedPreviewSettings.followThemeSepiaModeDefaultsKey)
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
        userDefaults.set(resolved, forKey: SharedPreviewSettings.followThemeSepiaDefaultsKey)
    }
}
