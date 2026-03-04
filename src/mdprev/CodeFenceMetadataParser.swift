import Foundation

struct CodeFenceMetadata: Equatable {
    let language: String?
    let fileName: String?
}

enum CodeFenceMetadataParser {
    static func extract(from markdown: String) -> [CodeFenceMetadata] {
        let normalizedMarkdown = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedMarkdown.split(separator: "\n", omittingEmptySubsequences: false)

        var metadataList: [CodeFenceMetadata] = []
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

            metadataList.append(parseInfoString(openingFence.infoString))
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

    private static func parseInfoString(_ infoString: String) -> CodeFenceMetadata {
        guard !infoString.isEmpty else {
            return CodeFenceMetadata(language: nil, fileName: nil)
        }

        if let attributeMetadata = parsePandocAttributeInfo(infoString) {
            return attributeMetadata
        }

        let tokens = splitInfoTokens(infoString)
        guard !tokens.isEmpty else {
            return CodeFenceMetadata(language: nil, fileName: nil)
        }

        var language: String?
        var fileName: String?

        if let firstToken = tokens.first {
            if let keyValue = parseKeyValueToken(firstToken) {
                if isFileNameKey(keyValue.key) {
                    fileName = keyValue.value
                }
            } else if looksLikeFileName(firstToken) {
                fileName = normalizeToken(firstToken)
            } else {
                language = normalizeToken(firstToken)
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

            if isCodeFenceControlToken(token) {
                continue
            }

            if looksLikeFileName(token) || isQuotedToken(token) {
                fileName = normalizeToken(token)
            }
        }

        return CodeFenceMetadata(language: language, fileName: fileName)
    }

    private static func parsePandocAttributeInfo(_ infoString: String) -> CodeFenceMetadata? {
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

            let normalized = normalizeToken(token)
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

        return CodeFenceMetadata(language: language, fileName: fileName)
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

        return (key: rawKey.lowercased(), value: normalizeToken(rawValue))
    }

    private static func normalizeToken(_ token: String) -> String {
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

    private static func isQuotedToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return false
        }

        return (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
            (trimmed.hasPrefix("'") && trimmed.hasSuffix("'"))
    }

    private static func isFileNameKey(_ key: String) -> Bool {
        ["file", "filename", "title", "path", "name"].contains(key)
    }

    private static func isCodeFenceControlToken(_ token: String) -> Bool {
        let normalized = normalizeToken(token)
        let lowercased = normalized.lowercased()

        if lowercased == "showlinenumbers" || lowercased == "linenumbers" || lowercased == "linenos" {
            return true
        }

        if lowercased.hasPrefix("showlinenumbers=") ||
            lowercased.hasPrefix("linenumbers=") ||
            lowercased.hasPrefix("linenos=") {
            return true
        }

        guard normalized.hasPrefix("{"), normalized.hasSuffix("}") else {
            return false
        }

        let body = normalized.dropFirst().dropLast()
        guard !body.isEmpty else {
            return false
        }

        return body.allSatisfy { char in
            char.isNumber || char == "," || char == "-" || char == " "
        }
    }

    private static func looksLikeFileName(_ token: String) -> Bool {
        let normalized = normalizeToken(token)
        return normalized.contains(".") || normalized.contains("/") || normalized.contains("\\")
    }
}
