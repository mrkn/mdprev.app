import Foundation

enum LocalFileLinkAction: Equatable {
    case openMarkdownInNewWindow(URL)
    case revealParentDirectory(URL)
    case missingFile(URL)
}

enum LocalFileLinkResolver {
    static func resolve(_ fileURL: URL) -> LocalFileLinkAction {
        let normalizedURL = fileURL.standardizedFileURL

        guard FileManager.default.fileExists(atPath: normalizedURL.path) else {
            return .missingFile(normalizedURL)
        }

        let ext = normalizedURL.pathExtension.lowercased()
        if ext == "md" || ext == "markdown" {
            return .openMarkdownInNewWindow(normalizedURL)
        }

        return .revealParentDirectory(normalizedURL.deletingLastPathComponent())
    }
}
