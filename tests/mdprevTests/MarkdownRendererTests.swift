import XCTest
@testable import mdprev

final class MarkdownRendererTests: XCTestCase {
    func testRenderReturnsHTMLDocumentForMarkdownInput() {
        let renderer = MarkdownRenderer()

        let output = renderer.renderHTML("# Title\n\nParagraph")

        XCTAssertTrue(output.contains("<html>"))
        XCTAssertTrue(output.contains("<h1>Title</h1>"))
    }

    func testCMarkRendersGFMTableToHTML() {
        let renderer = CMarkGFMRenderer()
        let markdown = """
        | A | B |
        | - | - |
        | 1 | 2 |
        """

        let html = renderer.renderHTMLBody(markdown)

        XCTAssertNotNil(html)
        XCTAssertTrue(html?.contains("<table>") ?? false)
        XCTAssertTrue(html?.contains("<th>A</th>") ?? false)
    }

    func testCMarkRendersStrikethroughToHTML() {
        let renderer = CMarkGFMRenderer()

        let html = renderer.renderHTMLBody("~~obsolete~~")

        XCTAssertNotNil(html)
        XCTAssertTrue(html?.contains("<del>") ?? false)
    }

    func testRendererUsesTableStylesThatFitViewport() {
        let renderer = MarkdownRenderer()

        let output = renderer.renderHTML("| A |\n| - |\n| veryveryveryveryveryveryveryveryveryveryveryveryverylongtext |")

        XCTAssertTrue(output.contains("table-layout: fixed;"))
        XCTAssertTrue(output.contains("overflow-wrap: anywhere;"))
        XCTAssertFalse(output.contains("white-space: nowrap;"))
    }

    func testRendererAddsLineNumbersToFencedCodeBlocks() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```swift
        let a = 1
        let b = 2
        ```
        """

        let output = renderer.renderHTML(markdown)

        XCTAssertTrue(output.contains("class=\"mdprev-code-line-number\""))
        XCTAssertTrue(output.contains("aria-hidden=\"true\">1</span>"))
        XCTAssertTrue(output.contains("aria-hidden=\"true\">2</span>"))
        XCTAssertFalse(output.contains("mdprev-code-line::before"))
    }

    func testRendererUsesNonSelectableLineNumbers() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```text
        hello
        ```
        """

        let output = renderer.renderHTML(markdown)

        XCTAssertTrue(output.contains("user-select: none;"))
        XCTAssertTrue(output.contains("-webkit-user-select: none;"))
    }

    func testRendererDoesNotInsertNewlineTextNodesBetweenCodeLines() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```text
        a
        b
        ```
        """

        let output = renderer.renderHTML(markdown)

        XCTAssertTrue(output.contains("</span></span><span class=\"mdprev-code-line\">"))
    }

    func testRendererUsesSepiaThemeColorsWhenConfigured() {
        let renderer = MarkdownRenderer()

        let output = renderer.renderHTML("body", baseFontSize: 16, theme: .sepia)

        XCTAssertTrue(output.contains("color-scheme: light;"))
        XCTAssertTrue(output.contains("--bg: #f7f0dd;"))
        XCTAssertTrue(output.contains("--link: #0f5e9c;"))
        XCTAssertFalse(output.contains("prefers-color-scheme: dark"))
    }

    func testRendererIncludesDarkModeMediaQueryForSystemTheme() {
        let renderer = MarkdownRenderer()

        let output = renderer.renderHTML("body", baseFontSize: 16, theme: .system)

        XCTAssertTrue(output.contains("color-scheme: light dark;"))
        XCTAssertTrue(output.contains("@media (prefers-color-scheme: dark)"))
    }

    func testRendererEmbedsConfiguredBaseFontSize() {
        let renderer = MarkdownRenderer()

        let output = renderer.renderHTML("body", baseFontSize: 21)

        XCTAssertTrue(output.contains("font-size: 21px;"))
    }

    func testPlaceholderRendersRecentFilesAsOpenLinks() {
        let fileURL = URL(fileURLWithPath: "/tmp/sample.md")

        let output = MarkdownRenderer.placeholderHTML(
            "Open a Markdown file to start previewing.",
            recentFiles: [fileURL]
        )

        XCTAssertTrue(output.contains("Recent Files"))
        XCTAssertTrue(output.contains("sample.md"))
        XCTAssertTrue(output.contains("mdprev-open-file://open?path="))
    }
}
