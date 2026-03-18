import Foundation
import XCTest
import MDPrevRendering
@testable import mdprev

@MainActor
final class AppModelThemeTests: XCTestCase {
    func testPreviewThemeDefaultsToSystem() {
        let defaults = makeIsolatedDefaults()
        let model = makeModel(defaults: defaults, suffix: "default")

        XCTAssertEqual(model.previewTheme, .system)
        XCTAssertEqual(model.syntaxHighlightTheme, .followPreview)
        XCTAssertTrue(model.renderedHTML.contains("color-scheme: light dark;"))
    }

    func testPreviewThemePersistsAcrossModelRecreation() {
        let defaults = makeIsolatedDefaults()
        let model = makeModel(defaults: defaults, suffix: "persist")

        model.setPreviewTheme(.sepia)

        let reloaded = makeModel(defaults: defaults, suffix: "persist")
        XCTAssertEqual(reloaded.previewTheme, .sepia)
        XCTAssertTrue(reloaded.renderedHTML.contains("--bg: #f7f0dd;"))
    }

    func testSyntaxThemePersistsAcrossModelRecreation() {
        let defaults = makeIsolatedDefaults()
        let model = makeModel(defaults: defaults, suffix: "syntax")

        model.setSyntaxHighlightTheme(.atomOneDark)

        let reloaded = makeModel(defaults: defaults, suffix: "syntax")
        XCTAssertEqual(reloaded.syntaxHighlightTheme, .atomOneDark)
        XCTAssertTrue(reloaded.renderedHTML.contains("mdprev-hljs-theme:atom-one-dark"))
    }

    func testDisabledSyntaxHighlightPersistsAcrossModelRecreation() {
        let defaults = makeIsolatedDefaults()
        let model = makeModel(defaults: defaults, suffix: "syntax-disabled")

        model.setSyntaxHighlightTheme(.disabled)

        let reloaded = makeModel(defaults: defaults, suffix: "syntax-disabled")
        XCTAssertEqual(reloaded.syntaxHighlightTheme, .disabled)
        XCTAssertFalse(reloaded.renderedHTML.contains("window.hljs"))
        XCTAssertFalse(reloaded.renderedHTML.contains("mdprev-hljs-theme:"))
    }

    private func makeModel(defaults: UserDefaults, suffix: String) -> AppModel {
        let store = RecentFilesStore(
            userDefaults: defaults,
            defaultsKey: "recent.theme.\(suffix)"
        )

        return AppModel(
            syntaxHighlightSettingsStore: SyntaxHighlightSettingsStore(userDefaults: defaults),
            userDefaults: defaults,
            recentFilesStore: store
        )
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "mdprev.tests.theme.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
