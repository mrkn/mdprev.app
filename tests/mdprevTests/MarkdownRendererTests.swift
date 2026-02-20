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
