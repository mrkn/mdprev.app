import XCTest
import MDPrevRendering
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

    func testRendererShowsLanguageHeaderForFencedCodeBlocks() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```python
        print("hi")
        ```
        """

        let output = renderer.renderHTML(markdown)

        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-header\""))
        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-language\">python</span>"))
        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-container\" data-language=\"python\""))
    }

    func testRendererShowsFileNameHeaderWhenSpecifiedInFenceInfo() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```swift filename=\"main.swift\"
        print("hi")
        ```
        """

        let output = renderer.renderHTML(markdown)

        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-filename\">main.swift</span>"))
    }

    func testRendererSupportsPandocFenceAttributesForLanguageAndFileName() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```{#snippet .python .numberLines filename=\"src/main.py\"}
        print("hi")
        ```
        """

        let output = renderer.renderHTML(markdown)

        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-language\">python</span>"))
        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-filename\">src/main.py</span>"))
        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-container\" data-language=\"python\""))
    }

    func testRendererSupportsDocusaurusStyleTitleMetadata() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```tsx {1,3-4} showLineNumbers title=\"/src/App.tsx\"
        console.log("hi")
        ```
        """

        let output = renderer.renderHTML(markdown)

        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-language\">tsx</span>"))
        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-filename\">/src/App.tsx</span>"))
    }

    func testRendererDoesNotTreatLineHighlightMetadataAsFileName() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```swift {2}
        let x = 1
        ```
        """

        let output = renderer.renderHTML(markdown)

        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-language\">swift</span>"))
        XCTAssertFalse(output.contains("class=\"mdprev-codeblock-filename\">{2}</span>"))
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

    func testRendererEmbedsHighlightBootstrapScript() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```swift
        let a = 1
        ```
        """

        let output = renderer.renderHTML(markdown)

        XCTAssertTrue(output.contains(HighlightJSSupport.bootstrapMarker))
        XCTAssertTrue(output.contains("window.hljs"))
        XCTAssertTrue(output.contains("Highlight.js v11.11.1"))
    }

    func testRendererAppliesHighlightThemeClassToCodeElement() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```swift
        let a = 1
        ```
        """

        let output = renderer.renderHTML(markdown)

        XCTAssertTrue(output.contains("codeElement.classList.add('hljs');"))
        XCTAssertTrue(output.contains("pre.mdprev-codeblock code.hljs {"))
        XCTAssertFalse(output.contains(".mdprev-code-line-text.hljs"))
    }

    func testRendererDisablesSyntaxHighlightWhenDisabledThemeIsSelected() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```swift
        let a = 1
        ```
        """

        let output = renderer.renderHTML(
            markdown,
            baseFontSize: 16,
            theme: .light,
            syntaxTheme: .disabled
        )

        XCTAssertFalse(output.contains(HighlightJSSupport.bootstrapMarker))
        XCTAssertFalse(output.contains("window.hljs"))
        XCTAssertFalse(output.contains("mdprev-hljs-theme:"))
    }

    func testRendererUsesConfiguredSyntaxThemeCSS() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```swift
        let a = 1
        ```
        """

        let output = renderer.renderHTML(
            markdown,
            baseFontSize: 16,
            theme: .light,
            syntaxTheme: .atomOneDark
        )

        XCTAssertTrue(output.contains("mdprev-hljs-theme:atom-one-dark"))
        XCTAssertFalse(output.contains("mdprev-hljs-theme:github-dark"))
    }

    func testRendererFollowPreviewSyntaxThemeUsesDarkCSSForDarkPreview() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```swift
        let a = 1
        ```
        """

        let output = renderer.renderHTML(
            markdown,
            baseFontSize: 16,
            theme: .dark,
            syntaxTheme: .followPreview
        )

        XCTAssertTrue(output.contains("mdprev-hljs-theme:github-dark"))
        XCTAssertFalse(output.contains("mdprev-hljs-theme:github */"))
    }

    func testRendererFollowPreviewSyntaxThemeUsesConfiguredThemes() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```swift
        let a = 1
        ```
        """

        let output = renderer.renderHTML(
            markdown,
            baseFontSize: 16,
            theme: .system,
            syntaxTheme: .followPreview,
            followThemeLightIdentifier: SyntaxHighlightTheme.xcode.rawValue,
            followThemeDarkIdentifier: SyntaxHighlightTheme.atomOneDark.rawValue
        )

        XCTAssertTrue(output.contains("mdprev-hljs-theme:xcode"))
        XCTAssertTrue(output.contains("mdprev-hljs-theme:atom-one-dark"))
        XCTAssertFalse(output.contains("mdprev-hljs-theme:github-dark"))
    }

    func testRendererFollowPreviewSyntaxThemeUsesConfiguredSepiaTheme() {
        let renderer = MarkdownRenderer()
        let markdown = """
        ```swift
        let a = 1
        ```
        """

        let output = renderer.renderHTML(
            markdown,
            baseFontSize: 16,
            theme: .sepia,
            syntaxTheme: .followPreview,
            followThemeLightIdentifier: SyntaxHighlightTheme.github.rawValue,
            followThemeDarkIdentifier: SyntaxHighlightTheme.githubDark.rawValue,
            followThemeSepiaIdentifier: SyntaxHighlightTheme.xcode.rawValue
        )

        XCTAssertTrue(output.contains("mdprev-hljs-theme:xcode"))
        XCTAssertFalse(output.contains("mdprev-hljs-theme:github-dark"))
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

    func testRendererProcessesTESTMarkdownWithHighlightAssets() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TEST.md")
        let markdown = try String(contentsOf: fixtureURL, encoding: .utf8)

        let renderer = MarkdownRenderer()
        let output = renderer.renderHTML(markdown)

        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-language\">py</span>"))
        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-filename\">test.py</span>"))
        XCTAssertTrue(output.contains("class=\"mdprev-codeblock-container\" data-language=\"py\""))
        XCTAssertTrue(output.contains("Highlight.js v11.11.1"))
    }
}
