import XCTest
@testable import MDPrevRendering

final class SharedPreviewSettingsTests: XCTestCase {
    func testCurrentValuesReadsThemeAndFontSettings() {
        let defaults = makeIsolatedDefaults()
        defaults.set(18, forKey: SharedPreviewSettings.baseFontSizeDefaultsKey)
        defaults.set(PreviewTheme.sepia.rawValue, forKey: SharedPreviewSettings.previewThemeDefaultsKey)
        defaults.set(SyntaxHighlightTheme.githubDark.rawValue, forKey: SharedPreviewSettings.syntaxThemeDefaultsKey)
        defaults.set("xcode", forKey: SharedPreviewSettings.followThemeLightDefaultsKey)
        defaults.set("atom-one-dark", forKey: SharedPreviewSettings.followThemeDarkDefaultsKey)
        defaults.set(FollowThemeSepiaMode.custom.rawValue, forKey: SharedPreviewSettings.followThemeSepiaModeDefaultsKey)
        defaults.set("github", forKey: SharedPreviewSettings.followThemeSepiaDefaultsKey)

        let values = SharedPreviewSettings.currentValues(userDefaults: defaults)

        XCTAssertEqual(values.baseFontSize, 18)
        XCTAssertEqual(values.previewTheme, .sepia)
        XCTAssertEqual(values.syntaxHighlightTheme, .githubDark)
        XCTAssertEqual(values.followThemeLightIdentifier, "xcode")
        XCTAssertEqual(values.followThemeDarkIdentifier, "atom-one-dark")
        XCTAssertEqual(values.followThemeSepiaIdentifier, "github")
    }

    func testCurrentValuesUsesLightThemeForSepiaWhenConfigured() {
        let defaults = makeIsolatedDefaults()
        defaults.set("xcode", forKey: SharedPreviewSettings.followThemeLightDefaultsKey)
        defaults.set("github-dark", forKey: SharedPreviewSettings.followThemeDarkDefaultsKey)
        defaults.set(FollowThemeSepiaMode.sameAsLight.rawValue, forKey: SharedPreviewSettings.followThemeSepiaModeDefaultsKey)
        defaults.set("atom-one-dark", forKey: SharedPreviewSettings.followThemeSepiaDefaultsKey)

        let values = SharedPreviewSettings.currentValues(userDefaults: defaults)

        XCTAssertEqual(values.followThemeSepiaIdentifier, "xcode")
    }

    func testUserDefaultsMigratesLegacyStandardDefaultsIntoSharedSuite() {
        let sharedDefaults = makeIsolatedDefaults()
        let legacyDefaults = makeIsolatedDefaults()

        legacyDefaults.set(PreviewTheme.dark.rawValue, forKey: SharedPreviewSettings.previewThemeDefaultsKey)
        legacyDefaults.set(19, forKey: SharedPreviewSettings.baseFontSizeDefaultsKey)
        legacyDefaults.set(SyntaxHighlightTheme.github.rawValue, forKey: SharedPreviewSettings.syntaxThemeDefaultsKey)

        SharedPreviewSettings.migrateLegacySettingsIfNeeded(
            to: sharedDefaults,
            legacyDefaults: legacyDefaults
        )

        XCTAssertEqual(sharedDefaults.string(forKey: SharedPreviewSettings.previewThemeDefaultsKey), PreviewTheme.dark.rawValue)
        XCTAssertEqual(sharedDefaults.object(forKey: SharedPreviewSettings.baseFontSizeDefaultsKey) as? Int, 19)
        XCTAssertEqual(sharedDefaults.string(forKey: SharedPreviewSettings.syntaxThemeDefaultsKey), SyntaxHighlightTheme.github.rawValue)
        XCTAssertTrue(sharedDefaults.bool(forKey: SharedPreviewSettings.migrationCompletedDefaultsKey))
    }

    func testMigrationRepairsSharedSuiteEvenAfterCompletionFlagWasSetEarly() {
        let sharedDefaults = makeIsolatedDefaults()
        let legacyDefaults = makeIsolatedDefaults()

        sharedDefaults.set(true, forKey: SharedPreviewSettings.migrationCompletedDefaultsKey)
        legacyDefaults.set(PreviewTheme.sepia.rawValue, forKey: SharedPreviewSettings.previewThemeDefaultsKey)
        legacyDefaults.set(SyntaxHighlightTheme.githubDark.rawValue, forKey: SharedPreviewSettings.syntaxThemeDefaultsKey)

        SharedPreviewSettings.migrateLegacySettingsIfNeeded(
            to: sharedDefaults,
            legacyDefaults: legacyDefaults
        )

        XCTAssertEqual(
            sharedDefaults.string(forKey: SharedPreviewSettings.previewThemeDefaultsKey),
            PreviewTheme.sepia.rawValue
        )
        XCTAssertEqual(
            sharedDefaults.string(forKey: SharedPreviewSettings.syntaxThemeDefaultsKey),
            SyntaxHighlightTheme.githubDark.rawValue
        )
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "mdprev.tests.shared-preview-settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
