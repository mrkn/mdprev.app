import XCTest
@testable import mdprev

final class SyntaxHighlightThemeTests: XCTestCase {
    func testAllCasesIncludesFollowPreviewAndBuiltInThemes() {
        let themes = SyntaxHighlightTheme.allCases

        XCTAssertTrue(themes.contains(.disabled))
        XCTAssertTrue(themes.contains(.followPreview))
        XCTAssertTrue(themes.contains(SyntaxHighlightTheme(rawValue: "github")))
        XCTAssertTrue(themes.contains(SyntaxHighlightTheme(rawValue: "base16/3024")))
        XCTAssertGreaterThan(themes.count, 200)
    }

    func testStoredValueFallsBackToDefaultWhenUnknown() {
        let theme = SyntaxHighlightTheme(storedValue: "unknown-theme")

        XCTAssertEqual(theme, .followPreview)
    }

    func testDisplayNameUsesHumanReadableFormat() {
        let theme = SyntaxHighlightTheme(rawValue: "base16/atelier-cave-light")

        XCTAssertEqual(theme.displayName, "Base16 / Atelier Cave Light")
    }

    func testDisabledDisplayName() {
        XCTAssertEqual(SyntaxHighlightTheme.disabled.displayName, "Disabled")
        XCTAssertTrue(SyntaxHighlightTheme.disabled.isDisabled)
    }
}
