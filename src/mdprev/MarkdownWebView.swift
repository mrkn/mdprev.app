import AppKit
import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    let selectAllRequestID: UInt
    let onFileDrop: (URL) -> Void
    let onLocalFileLinkActivated: (URL, LinkOpenDisposition) -> Void
    let onExternalURLActivated: (URL) -> Void
    @Binding var isDropTargeted: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> FileDropWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        let linkTooltipScript = WKUserScript(
            source: Self.linkHrefTooltipScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(linkTooltipScript)
        configuration.userContentController = userContentController

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
            context.coordinator.lastLoadedBaseURL = baseURL?.standardizedFileURL
            webView.loadHTMLString(html, baseURL: baseURL)
        } else if context.coordinator.lastLoadedBaseURL != baseURL?.standardizedFileURL {
            context.coordinator.lastLoadedBaseURL = baseURL?.standardizedFileURL
            webView.loadHTMLString(html, baseURL: baseURL)
        }

        if context.coordinator.lastHandledSelectAllRequestID != selectAllRequestID {
            context.coordinator.lastHandledSelectAllRequestID = selectAllRequestID
            webView.selectAllHTMLContent()
        }
    }

    private static let linkHrefTooltipDelayMilliseconds = 200

    private static var linkHrefTooltipScript: String {
        """
        (() => {
          const delayMs = \(linkHrefTooltipDelayMilliseconds);
          const anchors = Array.from(document.querySelectorAll('a[href]'));
          if (anchors.length === 0) return;

          const tooltip = document.createElement('div');
          tooltip.id = 'mdprev-link-tooltip';
          tooltip.style.position = 'fixed';
          tooltip.style.left = '0';
          tooltip.style.top = '0';
          tooltip.style.zIndex = '2147483647';
          tooltip.style.pointerEvents = 'none';
          tooltip.style.maxWidth = 'min(75vw, 900px)';
          tooltip.style.padding = '6px 8px';
          tooltip.style.borderRadius = '6px';
          tooltip.style.border = '1px solid rgba(127, 127, 127, 0.55)';
          tooltip.style.background = 'rgba(20, 20, 20, 0.92)';
          tooltip.style.color = '#f3f3f3';
          tooltip.style.font = '12px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
          tooltip.style.lineHeight = '1.35';
          tooltip.style.whiteSpace = 'pre-wrap';
          tooltip.style.wordBreak = 'break-all';
          tooltip.style.opacity = '0';
          tooltip.style.transition = 'opacity 80ms linear';
          document.documentElement.appendChild(tooltip);

          let showTimer = null;
          let activeAnchor = null;
          let latestX = 0;
          let latestY = 0;

          const clearShowTimer = () => {
            if (showTimer !== null) {
              clearTimeout(showTimer);
              showTimer = null;
            }
          };

          const hideTooltip = () => {
            clearShowTimer();
            tooltip.style.opacity = '0';
            activeAnchor = null;
          };

          const positionTooltip = () => {
            const offsetX = 14;
            const offsetY = 18;
            const margin = 10;

            tooltip.style.left = '0px';
            tooltip.style.top = '0px';
            const width = tooltip.offsetWidth;
            const height = tooltip.offsetHeight;

            let x = latestX + offsetX;
            let y = latestY + offsetY;

            if (x + width > window.innerWidth - margin) {
              x = Math.max(margin, window.innerWidth - width - margin);
            }
            if (y + height > window.innerHeight - margin) {
              y = Math.max(margin, latestY - height - offsetY);
            }

            tooltip.style.left = `${x}px`;
            tooltip.style.top = `${y}px`;
          };

          const showTooltip = (anchor) => {
            const href = anchor.getAttribute('href');
            if (!href) return;
            activeAnchor = anchor;
            tooltip.textContent = href;
            tooltip.style.opacity = '1';
            positionTooltip();
          };

          const scheduleShow = (anchor) => {
            clearShowTimer();
            showTimer = setTimeout(() => {
              showTimer = null;
              showTooltip(anchor);
            }, delayMs);
          };

          anchors.forEach((anchor) => {
            const href = anchor.getAttribute('href');
            if (!href) return;

            anchor.addEventListener('mouseenter', (event) => {
              latestX = event.clientX;
              latestY = event.clientY;
              scheduleShow(anchor);
            });

            anchor.addEventListener('mousemove', (event) => {
              latestX = event.clientX;
              latestY = event.clientY;
              if (activeAnchor === anchor) {
                positionTooltip();
                return;
              }

              if (showTimer === null) {
                scheduleShow(anchor);
              }
            });

            anchor.addEventListener('mouseleave', () => {
              if (activeAnchor === anchor) {
                hideTooltip();
              } else {
                clearShowTimer();
              }
            });

            anchor.addEventListener('mousedown', hideTooltip);
            anchor.addEventListener('click', hideTooltip);
            anchor.addEventListener('blur', hideTooltip);
          });

          window.addEventListener('scroll', hideTooltip, { passive: true });
          window.addEventListener('blur', hideTooltip);
        })();
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView
        var lastLoadedHTML: String?
        var lastLoadedBaseURL: URL?
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
            let disposition = LinkOpenDisposition.from(modifierFlags: navigationAction.modifierFlags)

            if let fileURL = Self.localFileURLFromActivatedLink(url) {
                Task { @MainActor in
                    parent.onLocalFileLinkActivated(fileURL, disposition)
                }
                decisionHandler(.cancel)
                return
            }

            Task { @MainActor in
                parent.onExternalURLActivated(url)
            }
            decisionHandler(.cancel)
        }

        private static func localFileURLFromActivatedLink(_ url: URL) -> URL? {
            if url.isFileURL {
                return url.standardizedFileURL
            }

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
