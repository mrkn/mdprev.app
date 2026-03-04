import AppKit
import Foundation
import UniformTypeIdentifiers

protocol FileOpenServicing {
    @MainActor
    func chooseFileURL() -> URL?
    func readMarkdown(from fileURL: URL) throws -> String
    func fileExists(at fileURL: URL) -> Bool
}

struct FileOpenService: FileOpenServicing {
    @MainActor
    func chooseFileURL() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose a Markdown file"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.supportedContentTypes

        if panel.runModal() == .OK, let fileURL = panel.url {
            return fileURL.standardizedFileURL
        }

        return nil
    }

    func readMarkdown(from fileURL: URL) throws -> String {
        try String(contentsOf: fileURL, encoding: .utf8)
    }

    func fileExists(at fileURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    private static let supportedContentTypes: [UTType] = {
        var types: [UTType] = [.plainText, .utf8PlainText, .text]

        if let md = UTType(filenameExtension: "md") {
            types.append(md)
        }
        if let markdown = UTType(filenameExtension: "markdown") {
            types.append(markdown)
        }

        return types
    }()
}
