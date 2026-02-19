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
}
