import Foundation

struct HighlightJSThemeDefinition: Hashable {
    let identifier: String
    let displayName: String
}

enum HighlightJSThemeCatalog {
    static let followPreviewLightIdentifier = "github"
    static let followPreviewDarkIdentifier = "github-dark"

    static var availableThemes: [HighlightJSThemeDefinition] {
        themeEntries
            .map(\.definition)
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    static func contains(identifier: String) -> Bool {
        themeEntriesByIdentifier[identifier] != nil
    }

    static func displayName(for identifier: String) -> String {
        themeEntriesByIdentifier[identifier]?.definition.displayName ?? humanizedDisplayName(for: identifier)
    }

    static func css(for identifier: String) -> String? {
        themeEntriesByIdentifier[identifier]?.css
    }

    static var resolvedFollowPreviewLightIdentifier: String {
        preferredIdentifier(primary: followPreviewLightIdentifier, fallback: followPreviewDarkIdentifier)
    }

    static var resolvedFollowPreviewDarkIdentifier: String {
        preferredIdentifier(primary: followPreviewDarkIdentifier, fallback: followPreviewLightIdentifier)
    }

    private static var themeEntries: [ThemeEntry] {
        Array(themeEntriesByIdentifier.values)
    }

    private static let themeEntriesByIdentifier: [String: ThemeEntry] = loadThemeEntriesByIdentifier()

    private static func preferredIdentifier(primary: String, fallback: String) -> String {
        if contains(identifier: primary) {
            return primary
        }

        if contains(identifier: fallback) {
            return fallback
        }

        return availableThemes.first?.identifier ?? primary
    }

    private static func loadThemeEntriesByIdentifier() -> [String: ThemeEntry] {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle.main
#endif

        let stylesDirectoryURL = bundle.resourceURL?.appendingPathComponent("highlightjs/styles", isDirectory: true)

        let candidateURLs: [URL]
        if let nestedURLs = bundle.urls(forResourcesWithExtension: "css", subdirectory: "highlightjs/styles"),
           !nestedURLs.isEmpty {
            candidateURLs = nestedURLs
        } else {
            let rootURLs = bundle.urls(forResourcesWithExtension: "css", subdirectory: nil) ?? []
            candidateURLs = rootURLs.filter { $0.lastPathComponent.hasSuffix(".min.css") }
        }

        var entriesByIdentifier: [String: ThemeEntry] = [:]
        for fileURL in candidateURLs {
            guard let identifier = themeIdentifier(for: fileURL, stylesDirectoryURL: stylesDirectoryURL),
                  let css = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            // Only treat highlight.js themes as candidates.
            guard css.contains(".hljs") else {
                continue
            }

            let definition = HighlightJSThemeDefinition(
                identifier: identifier,
                displayName: humanizedDisplayName(for: identifier)
            )
            entriesByIdentifier[identifier] = ThemeEntry(definition: definition, css: css)
        }

        return entriesByIdentifier
    }

    private static func themeIdentifier(for fileURL: URL, stylesDirectoryURL: URL?) -> String? {
        let relativePath = relativeThemePath(for: fileURL, stylesDirectoryURL: stylesDirectoryURL)
        guard relativePath.hasSuffix(".min.css") else {
            return nil
        }

        let trimmed = String(relativePath.dropLast(".min.css".count))
        return trimmed.replacingOccurrences(of: "__", with: "/")
    }

    private static func relativeThemePath(for fileURL: URL, stylesDirectoryURL: URL?) -> String {
        guard let stylesDirectoryURL else {
            return fileURL.lastPathComponent
        }

        let normalizedStylesPath = stylesDirectoryURL.standardizedFileURL.path
        let normalizedFilePath = fileURL.standardizedFileURL.path

        guard normalizedFilePath.hasPrefix(normalizedStylesPath + "/") else {
            return fileURL.lastPathComponent
        }

        return String(normalizedFilePath.dropFirst(normalizedStylesPath.count + 1))
    }

    private static func humanizedDisplayName(for identifier: String) -> String {
        identifier
            .split(separator: "/")
            .map { segment in
                segment
                    .split(separator: "-")
                    .map(humanizedWord(_:))
                    .joined(separator: " ")
            }
            .joined(separator: " / ")
    }

    private static func humanizedWord(_ rawWord: Substring) -> String {
        let word = String(rawWord)
        guard !word.isEmpty else {
            return word
        }

        if word.count <= 3 {
            return word.uppercased()
        }

        return word.prefix(1).uppercased() + word.dropFirst()
    }

    private struct ThemeEntry {
        let definition: HighlightJSThemeDefinition
        let css: String
    }
}
