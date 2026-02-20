import Foundation

struct ExternalURLInspection {
    enum Kind: Equatable {
        case skipped
        case response(statusCode: Int, redirectLocation: String?)
        case failed(String)
    }

    let kind: Kind

    var redirectLocation: String? {
        switch kind {
        case .response(_, let redirectLocation):
            return redirectLocation

        case .skipped, .failed:
            return nil
        }
    }
}

struct ExternalURLPromptContent: Equatable {
    let messageText: String
    let informativeText: String
    let showsWarningStyle: Bool
}

enum ExternalURLPromptBuilder {
    static func build(url: URL, inspection: ExternalURLInspection) -> ExternalURLPromptContent {
        var lines: [String] = [
            "URL:",
            url.absoluteString
        ]
        var showsWarningStyle = false

        switch inspection.kind {
        case .response(let statusCode, let redirectLocation):
            lines.append("")
            lines.append("HEAD status: \(statusCode)")
            if let redirectLocation {
                showsWarningStyle = true
                lines.append("Warning: This URL redirects.")
                lines.append("Location: \(redirectLocation)")
            }

        case .failed(let reason):
            showsWarningStyle = true
            lines.append("")
            lines.append("HEAD request failed: \(reason)")
            lines.append("Proceed only if you trust this URL.")

        case .skipped:
            showsWarningStyle = true
            lines.append("")
            lines.append("HEAD request skipped for this URL scheme.")
            lines.append("Proceed only if you trust this URL.")
        }

        return ExternalURLPromptContent(
            messageText: "Open External Link?",
            informativeText: lines.joined(separator: "\n"),
            showsWarningStyle: showsWarningStyle
        )
    }
}

enum ExternalURLInspector {
    static func inspect(_ url: URL) async -> ExternalURLInspection {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return ExternalURLInspection(kind: .skipped)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        let delegate = RedirectCaptureDelegate()
        let session = URLSession(
            configuration: .ephemeral,
            delegate: delegate,
            delegateQueue: nil
        )
        defer {
            session.invalidateAndCancel()
        }

        do {
            let (_, response) = try await session.data(for: request, delegate: delegate)
            guard let httpResponse = response as? HTTPURLResponse else {
                return ExternalURLInspection(kind: .failed("Unexpected response"))
            }

            let redirectLocation = delegate.redirectLocation ?? redirectLocation(from: httpResponse)
            return ExternalURLInspection(
                kind: .response(
                    statusCode: httpResponse.statusCode,
                    redirectLocation: redirectLocation
                )
            )
        } catch {
            return ExternalURLInspection(kind: .failed(error.localizedDescription))
        }
    }

    static func openWithOpenCommand(_ url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ExternalURLOpenError.nonZeroExit(process.terminationStatus)
        }
    }

    private static func redirectLocation(from response: HTTPURLResponse) -> String? {
        if let value = response.value(forHTTPHeaderField: "Location"), !value.isEmpty {
            return value
        }

        return nil
    }
}

private final class RedirectCaptureDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private(set) var redirectLocation: String?

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if redirectLocation == nil {
            if let location = response.value(forHTTPHeaderField: "Location"), !location.isEmpty {
                redirectLocation = location
            } else {
                redirectLocation = request.url?.absoluteString
            }
        }

        completionHandler(request)
    }
}

enum ExternalURLOpenError: LocalizedError {
    case nonZeroExit(Int32)

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let status):
            return "open command failed with exit status \(status)"
        }
    }
}
