import Foundation
import XCTest
import MDPrevRendering
@testable import mdprev

@MainActor
final class SyntaxHighlightSettingsStoreTests: XCTestCase {
    func testDefaultSelectionUsesCatalogDefaults() {
        let defaults = makeIsolatedDefaults()
        let store = SyntaxHighlightSettingsStore(userDefaults: defaults)

        XCTAssertEqual(
            store.followThemeLightIdentifier,
            HighlightJSThemeCatalog.resolvedFollowPreviewLightIdentifier
        )
        XCTAssertEqual(
            store.followThemeDarkIdentifier,
            HighlightJSThemeCatalog.resolvedFollowPreviewDarkIdentifier
        )
        XCTAssertEqual(store.followThemeSepiaMode, .sameAsLight)
        XCTAssertEqual(store.effectiveFollowThemeSepiaIdentifier, store.followThemeLightIdentifier)
    }

    func testSelectionPersistsAcrossRecreation() {
        let defaults = makeIsolatedDefaults()
        let store = SyntaxHighlightSettingsStore(userDefaults: defaults)

        store.setFollowThemeLightIdentifier(SyntaxHighlightTheme.xcode.rawValue)
        store.setFollowThemeDarkIdentifier(SyntaxHighlightTheme.atomOneDark.rawValue)
        store.setFollowThemeSepiaMode(.custom)
        store.setFollowThemeSepiaIdentifier(SyntaxHighlightTheme.github.rawValue)

        let reloaded = SyntaxHighlightSettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.followThemeLightIdentifier, SyntaxHighlightTheme.xcode.rawValue)
        XCTAssertEqual(reloaded.followThemeDarkIdentifier, SyntaxHighlightTheme.atomOneDark.rawValue)
        XCTAssertEqual(reloaded.followThemeSepiaMode, .custom)
        XCTAssertEqual(reloaded.followThemeSepiaIdentifier, SyntaxHighlightTheme.github.rawValue)
        XCTAssertEqual(reloaded.effectiveFollowThemeSepiaIdentifier, SyntaxHighlightTheme.github.rawValue)
    }

    func testInvalidThemeFallsBackToValidTheme() {
        let defaults = makeIsolatedDefaults()
        let store = SyntaxHighlightSettingsStore(userDefaults: defaults)

        store.setFollowThemeLightIdentifier("not-a-theme")
        store.setFollowThemeDarkIdentifier("still-not-a-theme")
        store.setFollowThemeSepiaMode(.custom)
        store.setFollowThemeSepiaIdentifier("still-invalid")

        XCTAssertTrue(HighlightJSThemeCatalog.contains(identifier: store.followThemeLightIdentifier))
        XCTAssertTrue(HighlightJSThemeCatalog.contains(identifier: store.followThemeDarkIdentifier))
        XCTAssertTrue(HighlightJSThemeCatalog.contains(identifier: store.followThemeSepiaIdentifier))
    }

    func testSepiaSameAsLightTracksLightSelection() {
        let defaults = makeIsolatedDefaults()
        let store = SyntaxHighlightSettingsStore(userDefaults: defaults)

        store.setFollowThemeSepiaMode(.sameAsLight)
        store.setFollowThemeLightIdentifier(SyntaxHighlightTheme.xcode.rawValue)

        XCTAssertEqual(store.effectiveFollowThemeSepiaIdentifier, SyntaxHighlightTheme.xcode.rawValue)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "mdprev.tests.syntax-highlight-settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
