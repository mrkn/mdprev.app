import Foundation
import cmark_gfm
import cmark_gfm_extensions

protocol MarkdownRenderingEngine {
    func renderHTML(_ markdown: String, baseFontSize: Double) -> String
}

struct MarkdownRenderer {
    private let engine: any MarkdownRenderingEngine

    init(engine: any MarkdownRenderingEngine = CMarkGFMRenderer()) {
        self.engine = engine
    }

    func renderHTML(_ markdown: String) -> String {
        renderHTML(markdown, baseFontSize: Self.defaultBaseFontSize)
    }

    func renderHTML(_ markdown: String, baseFontSize: Double) -> String {
        engine.renderHTML(markdown, baseFontSize: baseFontSize)
    }

    static func placeholderHTML(_ message: String, baseFontSize: Double = defaultBaseFontSize) -> String {
        CMarkGFMRenderer.wrapHTML("<p>\(escapeHTML(message))</p>", baseFontSize: baseFontSize)
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
}

struct CMarkGFMRenderer: MarkdownRenderingEngine {
    func renderHTML(_ markdown: String, baseFontSize: Double) -> String {
        guard let htmlBody = renderHTMLBody(markdown) else {
            let escaped = MarkdownRenderer.escapeHTML(markdown)
            return Self.wrapHTML("<pre><code>\(escaped)</code></pre>", baseFontSize: baseFontSize)
        }

        return Self.wrapHTML(htmlBody, baseFontSize: baseFontSize)
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

    static func wrapHTML(_ htmlBody: String, baseFontSize: Double = MarkdownRenderer.defaultBaseFontSize) -> String {
        let clampedFontSize = min(max(baseFontSize, 12), 30)
        let fontSizeValue = cssPixelValue(clampedFontSize)

        return """
        <!doctype html>
        <html>
          <head>
            <meta charset=\"utf-8\" />
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
            <style>
              :root {
                color-scheme: light dark;
                --text: #1f2328;
                --muted: #59636e;
                --bg: #ffffff;
                --code-bg: #f6f8fa;
                --border: #d0d7de;
                --row-alt: #f6f8fa;
              }

              @media (prefers-color-scheme: dark) {
                :root {
                  --text: #e6edf3;
                  --muted: #9da7b3;
                  --bg: #0d1117;
                  --code-bg: #161b22;
                  --border: #30363d;
                  --row-alt: #161b22;
                }
              }

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
                display: block;
                max-width: 100%;
                overflow-x: auto;
                white-space: nowrap;
              }

              table th,
              table td {
                border: 1px solid var(--border);
                padding: 6px 13px;
                vertical-align: top;
              }

              table th {
                font-weight: 600;
              }

              table tr:nth-child(2n) {
                background: var(--row-alt);
              }

              a {
                color: #0969da;
              }

              @media (prefers-color-scheme: dark) {
                a {
                  color: #58a6ff;
                }
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
}
