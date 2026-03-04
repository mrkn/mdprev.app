import Foundation
import cmark_gfm
import cmark_gfm_extensions

protocol MarkdownRenderingEngine {
    func renderHTML(_ markdown: String, baseFontSize: Double, theme: PreviewTheme) -> String
}

struct MarkdownRenderer {
    private let engine: any MarkdownRenderingEngine

    init(engine: any MarkdownRenderingEngine = CMarkGFMRenderer()) {
        self.engine = engine
    }

    func renderHTML(_ markdown: String) -> String {
        renderHTML(
            markdown,
            baseFontSize: Self.defaultBaseFontSize,
            theme: PreviewTheme.defaultTheme
        )
    }

    func renderHTML(
        _ markdown: String,
        baseFontSize: Double,
        theme: PreviewTheme = PreviewTheme.defaultTheme
    ) -> String {
        engine.renderHTML(markdown, baseFontSize: baseFontSize, theme: theme)
    }

    static func placeholderHTML(
        _ message: String,
        baseFontSize: Double = defaultBaseFontSize,
        theme: PreviewTheme = PreviewTheme.defaultTheme,
        recentFiles: [URL] = []
    ) -> String {
        var body = "<p>\(escapeHTML(message))</p>"

        if !recentFiles.isEmpty {
            body += "<section class=\"recent-files\">"
            body += "<h2>Recent Files</h2>"
            body += "<ul>"

            for fileURL in recentFiles {
                let title = escapeHTML(fileURL.lastPathComponent)
                let path = escapeHTML(fileURL.path)
                let href = openRecentFileHref(for: fileURL)
                body += """
                <li>
                  <a href="\(href)">\(title)</a>
                  <div class="recent-file-path">\(path)</div>
                </li>
                """
            }

            body += "</ul>"
            body += "</section>"
        }

        return CMarkGFMRenderer.wrapHTML(body, baseFontSize: baseFontSize, theme: theme)
    }

    static func escapeHTML(_ text: String) -> String {
        var escaped = text
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        return escaped
    }

    static let defaultBaseFontSize: Double = 16

    private static func openRecentFileHref(for fileURL: URL) -> String {
        let path = fileURL.standardizedFileURL.path
        var components = URLComponents()
        components.scheme = "mdprev-open-file"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "path", value: path)
        ]

        return components.string ?? "#"
    }
}

struct CMarkGFMRenderer: MarkdownRenderingEngine {
    func renderHTML(_ markdown: String, baseFontSize: Double, theme: PreviewTheme) -> String {
        guard let htmlBody = renderHTMLBody(markdown) else {
            let escaped = MarkdownRenderer.escapeHTML(markdown)
            let numberedFallback = Self.addLineNumbers(
                to: "<pre><code>\(escaped)</code></pre>"
            )
            return Self.wrapHTML(
                numberedFallback,
                baseFontSize: baseFontSize,
                theme: theme
            )
        }

        let numberedHTMLBody = Self.addLineNumbers(to: htmlBody)
        return Self.wrapHTML(numberedHTMLBody, baseFontSize: baseFontSize, theme: theme)
    }

    func renderHTMLBody(_ markdown: String) -> String? {
        cmark_gfm_core_extensions_ensure_registered()

        let options = CMARK_OPT_DEFAULT
        guard let parser = cmark_parser_new(options) else {
            return nil
        }

        defer {
            cmark_parser_free(parser)
        }

        let extensionNames = ["table", "strikethrough", "autolink", "tasklist", "tagfilter"]
        for name in extensionNames {
            name.withCString { cName in
                guard let syntax = cmark_find_syntax_extension(cName) else {
                    return
                }

                cmark_parser_attach_syntax_extension(parser, syntax)
            }
        }

        markdown.withCString { cMarkdown in
            cmark_parser_feed(parser, cMarkdown, strlen(cMarkdown))
        }

        guard let document = cmark_parser_finish(parser) else {
            return nil
        }

        defer {
            cmark_node_free(document)
        }

        let extensions = cmark_parser_get_syntax_extensions(parser)
        guard let rendered = cmark_render_html(document, options, extensions) else {
            return nil
        }

        defer {
            free(rendered)
        }

        return String(cString: rendered)
    }

    static func wrapHTML(
        _ htmlBody: String,
        baseFontSize: Double = MarkdownRenderer.defaultBaseFontSize,
        theme: PreviewTheme = PreviewTheme.defaultTheme
    ) -> String {
        let clampedFontSize = min(max(baseFontSize, 12), 30)
        let fontSizeValue = cssPixelValue(clampedFontSize)
        let rootVariables = cssVariables(theme.baseColors)
        let darkModeVariables = theme.darkModeCSSVariables
        let colorScheme = theme.colorScheme

        return """
        <!doctype html>
        <html>
          <head>
            <meta charset=\"utf-8\" />
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
            <style>
              :root {
                color-scheme: \(colorScheme);
                \(rootVariables)
              }

              \(darkModeVariables)

              body {
                margin: 0;
                padding: 24px;
                color: var(--text);
                background: var(--bg);
                font: -apple-system-body;
                font-size: \(fontSizeValue)px;
                line-height: 1.5;
                overflow-wrap: anywhere;
              }

              p, ul, ol, blockquote, pre, table {
                margin-top: 0;
                margin-bottom: 16px;
              }

              h1, h2, h3, h4, h5, h6 {
                margin: 24px 0 12px;
                line-height: 1.25;
              }

              h1 { font-size: 2em; }
              h2 { font-size: 1.5em; }
              h3 { font-size: 1.25em; }

              code, pre {
                font-family: Menlo, SFMono-Regular, ui-monospace, monospace;
                font-size: 0.92em;
              }

              pre {
                background: var(--code-bg);
                border-radius: 6px;
                border: 1px solid var(--border);
                padding: 12px;
                overflow-x: auto;
              }

              pre code {
                background: transparent;
                padding: 0;
              }

              pre.mdprev-codeblock {
                padding: 0;
              }

              pre.mdprev-codeblock code {
                display: block;
                padding: 12px 0;
              }

              pre.mdprev-codeblock .mdprev-code-line {
                display: grid;
                grid-template-columns: 44px minmax(0, 1fr);
                column-gap: 10px;
                align-items: baseline;
                padding: 0 12px;
                min-height: 1.5em;
              }

              pre.mdprev-codeblock .mdprev-code-line-number {
                text-align: right;
                color: var(--muted);
                opacity: 0.7;
                user-select: none;
                -webkit-user-select: none;
                pointer-events: none;
                font-variant-numeric: tabular-nums;
              }

              pre.mdprev-codeblock .mdprev-code-line-text {
                white-space: pre;
                overflow-wrap: normal;
                word-break: normal;
                min-width: 0;
              }

              code {
                background: var(--code-bg);
                border-radius: 4px;
                padding: 0.2em 0.35em;
              }

              blockquote {
                color: var(--muted);
                border-left: 3px solid var(--border);
                margin-left: 0;
                padding-left: 12px;
              }

              table {
                border-collapse: collapse;
                width: 100%;
                max-width: 100%;
                table-layout: fixed;
              }

              table th,
              table td {
                border: 1px solid var(--border);
                padding: 6px 13px;
                vertical-align: top;
                white-space: normal;
                overflow-wrap: anywhere;
                word-break: break-word;
              }

              table th {
                font-weight: 600;
              }

              table tr:nth-child(2n) {
                background: var(--row-alt);
              }

              a {
                color: var(--link);
              }

              .recent-files {
                margin-top: 28px;
              }

              .recent-files h2 {
                font-size: 1.05em;
                margin: 0 0 12px;
              }

              .recent-files ul {
                list-style: none;
                padding: 0;
                margin: 0;
              }

              .recent-files li {
                margin: 0;
                padding: 10px 12px;
                border: 1px solid var(--border);
                border-radius: 8px;
                background: var(--code-bg);
              }

              .recent-files li + li {
                margin-top: 10px;
              }

              .recent-file-path {
                margin-top: 4px;
                font-size: 0.86em;
                color: var(--muted);
                overflow-wrap: anywhere;
              }
            </style>
          </head>
          <body>
          \(htmlBody)
          </body>
        </html>
        """
    }

    private static func cssPixelValue(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    fileprivate static func cssVariables(_ colors: PreviewThemeColors) -> String {
        """
                --text: \(colors.text);
                --muted: \(colors.muted);
                --bg: \(colors.background);
                --code-bg: \(colors.codeBackground);
                --border: \(colors.border);
                --row-alt: \(colors.rowAlternate);
                --link: \(colors.link);
        """
    }

    private static func addLineNumbers(to htmlBody: String) -> String {
        let fullRange = NSRange(htmlBody.startIndex..<htmlBody.endIndex, in: htmlBody)
        let matches = codeBlockRegex.matches(in: htmlBody, options: [], range: fullRange)

        guard !matches.isEmpty else {
            return htmlBody
        }

        var result = htmlBody
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result),
                  let attributesRange = Range(match.range(at: 1), in: result),
                  let codeRange = Range(match.range(at: 2), in: result) else {
                continue
            }

            let attributes = String(result[attributesRange])
            let codeContent = String(result[codeRange])
            let numberedCodeContent = numberedCodeContent(from: codeContent)
            let replacement = "<pre class=\"mdprev-codeblock\"><code\(attributes)>\(numberedCodeContent)</code></pre>"
            result.replaceSubrange(matchRange, with: replacement)
        }

        return result
    }

    private static func numberedCodeContent(from encodedCodeContent: String) -> String {
        let hasTrailingNewline = encodedCodeContent.hasSuffix("\n")
        var lines = encodedCodeContent.components(separatedBy: "\n")

        if hasTrailingNewline, !lines.isEmpty {
            lines.removeLast()
        }

        if lines.isEmpty {
            lines = [""]
        }

        let numberedLines = lines.enumerated().map { index, line in
            """
            <span class="mdprev-code-line"><span class="mdprev-code-line-number" aria-hidden="true">\(index + 1)</span><span class="mdprev-code-line-text">\(line)</span></span>
            """
        }

        return numberedLines.joined()
    }

    private static let codeBlockRegex = try! NSRegularExpression(
        pattern: #"<pre><code([^>]*)>(.*?)</code></pre>"#,
        options: [.dotMatchesLineSeparators]
    )
}

fileprivate struct PreviewThemeColors {
    let text: String
    let muted: String
    let background: String
    let codeBackground: String
    let border: String
    let rowAlternate: String
    let link: String
}

private extension PreviewTheme {
    var colorScheme: String {
        switch self {
        case .system:
            return "light dark"
        case .light, .sepia:
            return "light"
        case .dark:
            return "dark"
        }
    }

    var baseColors: PreviewThemeColors {
        switch self {
        case .system, .light:
            return PreviewThemeColors(
                text: "#1f2328",
                muted: "#59636e",
                background: "#ffffff",
                codeBackground: "#f6f8fa",
                border: "#d0d7de",
                rowAlternate: "#f6f8fa",
                link: "#0969da"
            )
        case .dark:
            return PreviewThemeColors(
                text: "#e6edf3",
                muted: "#9da7b3",
                background: "#0d1117",
                codeBackground: "#161b22",
                border: "#30363d",
                rowAlternate: "#161b22",
                link: "#58a6ff"
            )
        case .sepia:
            return PreviewThemeColors(
                text: "#3a2f22",
                muted: "#6f624f",
                background: "#f7f0dd",
                codeBackground: "#efe5cc",
                border: "#d4c4a1",
                rowAlternate: "#f1e7d0",
                link: "#0f5e9c"
            )
        }
    }

    var darkModeCSSVariables: String {
        guard self == .system else {
            return ""
        }

        let darkColors = PreviewThemeColors(
            text: "#e6edf3",
            muted: "#9da7b3",
            background: "#0d1117",
            codeBackground: "#161b22",
            border: "#30363d",
            rowAlternate: "#161b22",
            link: "#58a6ff"
        )

        let darkVariables = CMarkGFMRenderer.cssVariables(darkColors)
        return """
              @media (prefers-color-scheme: dark) {
                :root {
                  \(darkVariables)
                }
              }
        """
    }
}
