import XCTest
@testable import mdprev

final class SyntaxHighlightThemeMenuModelTests: XCTestCase {
    func testMenuModelFiltersDisabledAndFollowPreviewThemes() {
        let model = SyntaxHighlightThemeMenuModel(
            themes: [
                .disabled,
                .followPreview,
                SyntaxHighlightTheme(rawValue: "github")
            ]
        )

        XCTAssertEqual(model.sections.count, 1)
        XCTAssertEqual(model.sections[0].letter, "G")
        XCTAssertEqual(model.sections[0].standaloneThemes, [SyntaxHighlightTheme(rawValue: "github")])
    }

    func testMenuModelGroupsBase16ThemesUnderBWithSubsections() {
        let model = SyntaxHighlightThemeMenuModel(
            themes: [
                SyntaxHighlightTheme(rawValue: "base16/3024"),
                SyntaxHighlightTheme(rawValue: "base16/apathy"),
                SyntaxHighlightTheme(rawValue: "brown-paper")
            ]
        )

        XCTAssertEqual(model.sections.count, 1)
        XCTAssertEqual(model.sections[0].letter, "B")
        XCTAssertEqual(model.sections[0].standaloneThemes, [SyntaxHighlightTheme(rawValue: "brown-paper")])
        XCTAssertEqual(model.sections[0].base16Subsections.map(\.letter), ["3", "A"])
        XCTAssertEqual(
            model.sections[0].base16Subsections[0].themes,
            [SyntaxHighlightTheme(rawValue: "base16/3024")]
        )
        XCTAssertEqual(
            model.sections[0].base16Subsections[1].themes,
            [SyntaxHighlightTheme(rawValue: "base16/apathy")]
        )
    }
}
