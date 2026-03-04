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
        let codeBlockMetadata = Self.extractFencedCodeMetadata(from: markdown)

        guard let htmlBody = renderHTMLBody(markdown) else {
            let escaped = MarkdownRenderer.escapeHTML(markdown)
            let numberedFallback = Self.addLineNumbers(
                to: "<pre><code>\(escaped)</code></pre>",
                metadata: codeBlockMetadata
            )
            return Self.wrapHTML(
                numberedFallback,
                baseFontSize: baseFontSize,
                theme: theme
            )
        }

        let numberedHTMLBody = Self.addLineNumbers(to: htmlBody, metadata: codeBlockMetadata)
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
                margin: 0;
                border: none;
                border-radius: 0;
                background: transparent;
              }

              .mdprev-codeblock-container {
                margin-top: 0;
                margin-bottom: 16px;
                background: var(--code-bg);
                border: 1px solid var(--border);
                border-radius: 6px;
                overflow: hidden;
              }

              .mdprev-codeblock-header {
                display: flex;
                align-items: center;
                gap: 10px;
                padding: 8px 12px;
                border-bottom: 1px solid var(--border);
                color: var(--muted);
                font-family: Menlo, SFMono-Regular, ui-monospace, monospace;
                font-size: 0.82em;
                line-height: 1.4;
                user-select: none;
                -webkit-user-select: none;
              }

              .mdprev-codeblock-language {
                color: var(--text);
                font-weight: 600;
              }

              .mdprev-codeblock-filename {
                overflow-wrap: anywhere;
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

    private static func addLineNumbers(to htmlBody: String, metadata: [CodeBlockMetadata]) -> String {
        let fullRange = NSRange(htmlBody.startIndex..<htmlBody.endIndex, in: htmlBody)
        let matches = codeBlockRegex.matches(in: htmlBody, options: [], range: fullRange)

        guard !matches.isEmpty else {
            return htmlBody
        }

        var result = htmlBody
        for (matchIndex, match) in matches.enumerated().reversed() {
            guard let matchRange = Range(match.range, in: result),
                  let preAttributesRange = Range(match.range(at: 1), in: result),
                  let codeAttributesRange = Range(match.range(at: 2), in: result),
                  let codeRange = Range(match.range(at: 3), in: result) else {
                continue
            }

            let preAttributes = String(result[preAttributesRange])
            let codeAttributes = String(result[codeAttributesRange])
            let codeContent = String(result[codeRange])
            let numberedCodeContent = numberedCodeContent(from: codeContent)
            let normalizedPreAttributes = mergedAttributes(preAttributes, addingClass: "mdprev-codeblock")
            let metadataForBlock: CodeBlockMetadata? = if matchIndex < metadata.count {
                metadata[matchIndex]
            } else {
                nil
            }
            let language = metadataForBlock?.language ?? languageFromCodeAttributes(codeAttributes)
            let fileName = metadataForBlock?.fileName
            let headerHTML = codeBlockHeaderHTML(language: language, fileName: fileName)
            let preHTML = "<pre\(normalizedPreAttributes)><code\(codeAttributes)>\(numberedCodeContent)</code></pre>"
            let replacement = "<div class=\"mdprev-codeblock-container\">\(headerHTML)\(preHTML)</div>"
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

        return numberedLines.joined() + (hasTrailingNewline ? "\n" : "")
    }

    private static func codeBlockHeaderHTML(language: String?, fileName: String?) -> String {
        var segments: [String] = []

        if let language = language?.trimmingCharacters(in: .whitespacesAndNewlines),
           !language.isEmpty {
            segments.append("<span class=\"mdprev-codeblock-language\">\(MarkdownRenderer.escapeHTML(language))</span>")
        }

        if let fileName = fileName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fileName.isEmpty {
            segments.append("<span class=\"mdprev-codeblock-filename\">\(MarkdownRenderer.escapeHTML(fileName))</span>")
        }

        guard !segments.isEmpty else {
            return ""
        }

        return "<div class=\"mdprev-codeblock-header\" aria-hidden=\"true\">\(segments.joined(separator: ""))</div>"
    }

    private static func mergedAttributes(_ attributes: String, addingClass className: String) -> String {
        let fullRange = NSRange(attributes.startIndex..<attributes.endIndex, in: attributes)
        guard let classMatch = classAttributeRegex.firstMatch(in: attributes, options: [], range: fullRange),
              let classValueRange = Range(classMatch.range(at: 1), in: attributes) else {
            return attributes + " class=\"\(className)\""
        }

        var classes = attributes[classValueRange].split(separator: " ").map(String.init)
        if !classes.contains(className) {
            classes.append(className)
        }

        var mergedAttributes = attributes
        mergedAttributes.replaceSubrange(classValueRange, with: classes.joined(separator: " "))
        return mergedAttributes
    }

    private static func languageFromCodeAttributes(_ attributes: String) -> String? {
        guard let classValue = attributeValue(named: "class", in: attributes) else {
            return attributeValue(named: "lang", in: attributes)
        }

        for className in classValue.split(separator: " ") {
            if className.hasPrefix("language-") {
                return String(className.dropFirst("language-".count))
            }
        }

        return attributeValue(named: "lang", in: attributes)
    }

    private static func attributeValue(named name: String, in attributes: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let regex = try! NSRegularExpression(
            pattern: #"\b\#(escapedName)\s*=\s*"([^"]*)""#,
            options: [.caseInsensitive]
        )
        let fullRange = NSRange(attributes.startIndex..<attributes.endIndex, in: attributes)
        guard let match = regex.firstMatch(in: attributes, options: [], range: fullRange),
              let valueRange = Range(match.range(at: 1), in: attributes) else {
            return nil
        }

        return String(attributes[valueRange])
    }

    private static func extractFencedCodeMetadata(from markdown: String) -> [CodeBlockMetadata] {
        let normalizedMarkdown = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedMarkdown.split(separator: "\n", omittingEmptySubsequences: false)

        var metadataList: [CodeBlockMetadata] = []
        var activeFence: (marker: Character, length: Int)?

        for rawLine in lines {
            let line = String(rawLine)

            if let activeFenceState = activeFence {
                if isClosingFence(
                    line,
                    marker: activeFenceState.marker,
                    minimumLength: activeFenceState.length
                ) {
                    activeFence = nil
                }
                continue
            }

            guard let openingFence = openingFence(in: line) else {
                continue
            }

            metadataList.append(parseCodeFenceInfo(openingFence.infoString))
            activeFence = (marker: openingFence.marker, length: openingFence.length)
        }

        return metadataList
    }

    private static func openingFence(in line: String) -> (marker: Character, length: Int, infoString: String)? {
        let leadingSpaces = line.prefix { $0 == " " }.count
        guard leadingSpaces <= 3 else {
            return nil
        }

        let body = line.dropFirst(leadingSpaces)
        guard let marker = body.first, marker == "`" || marker == "~" else {
            return nil
        }

        let fenceLength = body.prefix { $0 == marker }.count
        guard fenceLength >= 3 else {
            return nil
        }

        let infoString = body.dropFirst(fenceLength).trimmingCharacters(in: .whitespaces)
        if marker == "`", infoString.contains("`") {
            return nil
        }

        return (marker: marker, length: fenceLength, infoString: infoString)
    }

    private static func isClosingFence(_ line: String, marker: Character, minimumLength: Int) -> Bool {
        let leadingSpaces = line.prefix { $0 == " " }.count
        guard leadingSpaces <= 3 else {
            return false
        }

        let body = line.dropFirst(leadingSpaces)
        let fenceLength = body.prefix { $0 == marker }.count
        guard fenceLength >= minimumLength else {
            return false
        }

        let rest = body.dropFirst(fenceLength)
        return rest.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func parseCodeFenceInfo(_ infoString: String) -> CodeBlockMetadata {
        guard !infoString.isEmpty else {
            return CodeBlockMetadata(language: nil, fileName: nil)
        }

        if let attributeMetadata = parsePandocAttributeInfo(infoString) {
            return attributeMetadata
        }

        let tokens = splitInfoTokens(infoString)
        guard !tokens.isEmpty else {
            return CodeBlockMetadata(language: nil, fileName: nil)
        }

        var language: String?
        var fileName: String?

        if let firstToken = tokens.first {
            if let keyValue = parseKeyValueToken(firstToken) {
                if isFileNameKey(keyValue.key) {
                    fileName = keyValue.value
                }
            } else if looksLikeFileName(firstToken) {
                fileName = normalizeInfoToken(firstToken)
            } else {
                language = normalizeInfoToken(firstToken)
            }
        }

        for token in tokens.dropFirst() {
            if let keyValue = parseKeyValueToken(token) {
                if isFileNameKey(keyValue.key) {
                    fileName = keyValue.value
                }
                continue
            }

            guard fileName == nil else {
                continue
            }

            if language != nil || looksLikeFileName(token) {
                fileName = normalizeInfoToken(token)
            }
        }

        return CodeBlockMetadata(language: language, fileName: fileName)
    }

    private static func parsePandocAttributeInfo(_ infoString: String) -> CodeBlockMetadata? {
        let trimmedInfo = infoString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedInfo.hasPrefix("{"), trimmedInfo.hasSuffix("}") else {
            return nil
        }

        let contentStart = trimmedInfo.index(after: trimmedInfo.startIndex)
        let contentEnd = trimmedInfo.index(before: trimmedInfo.endIndex)
        let content = String(trimmedInfo[contentStart..<contentEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = splitInfoTokens(content)

        var language: String?
        var fileName: String?

        for token in tokens {
            if let keyValue = parseKeyValueToken(token), isFileNameKey(keyValue.key) {
                fileName = keyValue.value
                continue
            }

            let normalized = normalizeInfoToken(token)
            guard !normalized.isEmpty else {
                continue
            }

            if normalized.hasPrefix(".") {
                let className = String(normalized.dropFirst())
                if language == nil, !className.isEmpty {
                    language = className
                }
                continue
            }

            if normalized.hasPrefix("#") {
                continue
            }

            if language == nil {
                language = normalized
            }
        }

        return CodeBlockMetadata(language: language, fileName: fileName)
    }

    private static func splitInfoTokens(_ infoString: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?

        for char in infoString {
            if let currentQuote = quote {
                current.append(char)
                if char == currentQuote {
                    quote = nil
                }
                continue
            }

            if char == "\"" || char == "'" {
                quote = char
                current.append(char)
                continue
            }

            if char.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }

            current.append(char)
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private static func parseKeyValueToken(_ token: String) -> (key: String, value: String)? {
        guard let separatorIndex = token.firstIndex(of: "=") else {
            return nil
        }

        let rawKey = String(token[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = String(token[token.index(after: separatorIndex)...])

        guard !rawKey.isEmpty else {
            return nil
        }

        return (key: rawKey.lowercased(), value: normalizeInfoToken(rawValue))
    }

    private static func normalizeInfoToken(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return trimmed
        }

        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
            (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }

        return trimmed
    }

    private static func isFileNameKey(_ key: String) -> Bool {
        ["file", "filename", "title", "path", "name"].contains(key)
    }

    private static func looksLikeFileName(_ token: String) -> Bool {
        let normalized = normalizeInfoToken(token)
        return normalized.contains(".") || normalized.contains("/") || normalized.contains("\\")
    }

    private static let codeBlockRegex = try! NSRegularExpression(
        pattern: #"<pre([^>]*)><code([^>]*)>(.*?)</code></pre>"#,
        options: [.dotMatchesLineSeparators]
    )

    private static let classAttributeRegex = try! NSRegularExpression(
        pattern: #"\bclass\s*=\s*"([^"]*)""#,
        options: []
    )

    private struct CodeBlockMetadata {
        let language: String?
        let fileName: String?
    }
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
