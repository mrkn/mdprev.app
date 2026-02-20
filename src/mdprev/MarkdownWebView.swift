import AppKit
import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let selectAllRequestID: UInt
    let onFileDrop: (URL) -> Void
    @Binding var isDropTargeted: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> FileDropWebView {
        let configuration = WKWebViewConfiguration()
        let webView = FileDropWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsMagnification = false
        webView.underPageBackgroundColor = .clear
        webView.onFileDrop = { [weak coordinator = context.coordinator] fileURL in
            Task { @MainActor in
                coordinator?.handleDrop(fileURL)
            }
        }
        webView.onDragStateChange = { [weak coordinator = context.coordinator] targeted in
            Task { @MainActor in
                coordinator?.handleDragStateChange(targeted)
            }
        }
        return webView
    }

    func updateNSView(_ webView: FileDropWebView, context: Context) {
        context.coordinator.parent = self

        if context.coordinator.lastLoadedHTML != html {
            context.coordinator.lastLoadedHTML = html
            webView.loadHTMLString(html, baseURL: nil)
        }

        if context.coordinator.lastHandledSelectAllRequestID != selectAllRequestID {
            context.coordinator.lastHandledSelectAllRequestID = selectAllRequestID
            webView.selectAllHTMLContent()
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView
        var lastLoadedHTML: String?
        var lastHandledSelectAllRequestID: UInt = 0

        init(parent: MarkdownWebView) {
            self.parent = parent
        }

        @MainActor
        func handleDrop(_ fileURL: URL) {
            parent.isDropTargeted = false
            parent.onFileDrop(fileURL.standardizedFileURL)
        }

        @MainActor
        func handleDragStateChange(_ targeted: Bool) {
            parent.isDropTargeted = targeted
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if let fileURL = Self.fileURLForOpenAction(from: url) {
                Task { @MainActor in
                    self.handleDrop(fileURL)
                }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        private static func fileURLForOpenAction(from url: URL) -> URL? {
            guard url.scheme == "mdprev-open-file",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let path = components.queryItems?.first(where: { $0.name == "path" })?.value else {
                return nil
            }

            return URL(fileURLWithPath: path).standardizedFileURL
        }
    }
}

final class FileDropWebView: WKWebView {
    var onFileDrop: ((URL) -> Void)?
    var onDragStateChange: ((Bool) -> Void)?

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL, .URL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard Self.firstFileURL(from: sender.draggingPasteboard) != nil else {
            onDragStateChange?(false)
            return []
        }

        onDragStateChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard Self.firstFileURL(from: sender.draggingPasteboard) != nil else {
            onDragStateChange?(false)
            return []
        }

        onDragStateChange?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragStateChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        Self.firstFileURL(from: sender.draggingPasteboard) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer {
            onDragStateChange?(false)
        }

        guard let fileURL = Self.firstFileURL(from: sender.draggingPasteboard) else {
            return false
        }

        onFileDrop?(fileURL)
        return true
    }

    private static func firstFileURL(from pasteboard: NSPasteboard) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] {
            return urls.first(where: \.isFileURL)
        }

        if let value = pasteboard.string(forType: .fileURL), let url = URL(string: value), url.isFileURL {
            return url
        }

        return nil
    }

    func selectAllHTMLContent() {
        let script = """
        (function() {
          const selection = window.getSelection();
          if (!selection) return;
          selection.removeAllRanges();
          const range = document.createRange();
          range.selectNodeContents(document.body);
          selection.addRange(range);
        })();
        """
        evaluateJavaScript(script, completionHandler: nil)
    }
}
