import Cocoa
import MDPrevRendering
import Quartz

final class QuickLookPreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL.standardizedFileURL

        let reply = QLPreviewReply(
            dataOfContentType: .html,
            contentSize: CGSize(width: 900, height: 1200)
        ) { replyToUpdate in
            let markdown = try String(contentsOf: fileURL, encoding: .utf8)
            let settings = SharedPreviewSettings.currentValues(
                userDefaults: SharedPreviewSettings.userDefaults(migrateLegacySettings: false)
            )
            let renderedHTML = MarkdownRenderer().renderHTML(
                markdown,
                baseFontSize: settings.baseFontSize,
                theme: settings.previewTheme,
                syntaxTheme: settings.syntaxHighlightTheme,
                followThemeLightIdentifier: settings.followThemeLightIdentifier,
                followThemeDarkIdentifier: settings.followThemeDarkIdentifier,
                followThemeSepiaIdentifier: settings.followThemeSepiaIdentifier
            )
            let html = Self.injectBaseURL(fileURL.deletingLastPathComponent(), into: renderedHTML)
            replyToUpdate.stringEncoding = .utf8
            replyToUpdate.title = fileURL.lastPathComponent
            return Data(html.utf8)
        }

        reply.title = fileURL.lastPathComponent
        return reply
    }

    private static func injectBaseURL(_ baseURL: URL, into html: String) -> String {
        guard let insertionRange = html.range(of: "<head>") else {
            return html
        }

        let escapedURL = MarkdownRenderer.escapeHTML(baseURL.absoluteString)
        let baseTag = "<head><base href=\"\(escapedURL)\">"
        return html.replacingCharacters(in: insertionRange, with: baseTag)
    }
}
