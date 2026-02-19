import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedFileURL: URL?
    @Published var renderedHTML = MarkdownRenderer.placeholderHTML("Open a Markdown file to start previewing.")
    @Published var statusMessage = "No file selected."
    @Published var autoReloadEnabled = true {
        didSet {
            configureWatcher()
        }
    }
    @Published var lastReloadDate: Date?
    @Published private(set) var selectAllRequestID: UInt = 0

    private let renderer: MarkdownRenderer
    private var watcher: FileWatcher?
    private let windowBehaviorController = WindowBehaviorController()
    private var keyboardMonitor: Any?
    private var suppressCommandReleaseAfterSelectAll = false

    init(renderer: MarkdownRenderer = MarkdownRenderer()) {
        self.renderer = renderer
        installKeyboardMonitor()
    }

    func requestFileOpen() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Markdown file"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.supportedContentTypes

        if panel.runModal() == .OK, let fileURL = panel.url {
            openFile(fileURL)
        }
    }

    func openFile(_ fileURL: URL) {
        selectedFileURL = fileURL
        reload()
        configureWatcher()
    }

    func attachWindow(_ window: NSWindow) {
        windowBehaviorController.attach(window: window)
    }

    func requestSelectAll() {
        selectAllRequestID &+= 1
    }

    func reload() {
        guard let fileURL = selectedFileURL else {
            renderedHTML = MarkdownRenderer.placeholderHTML("Open a Markdown file to start previewing.")
            statusMessage = "No file selected."
            lastReloadDate = nil
            return
        }

        do {
            let markdown = try String(contentsOf: fileURL, encoding: .utf8)
            renderedHTML = renderer.renderHTML(markdown)
            statusMessage = "Previewing \(fileURL.lastPathComponent)"
            lastReloadDate = Date()
        } catch {
            renderedHTML = MarkdownRenderer.placeholderHTML("Failed to load file.")
            statusMessage = "Could not read \(fileURL.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func configureWatcher() {
        watcher?.stop()
        watcher = nil

        guard autoReloadEnabled, let fileURL = selectedFileURL else {
            return
        }

        do {
            let newWatcher = try FileWatcher(fileURL: fileURL) { [weak self] in
                Task { @MainActor in
                    self?.reload()
                }
            }
            try newWatcher.start()
            watcher = newWatcher
        } catch {
            statusMessage = "Failed to watch file: \(error.localizedDescription)"
        }
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

    private func installKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else {
                return event
            }

            switch event.type {
            case .keyDown:
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if flags == [.command], event.charactersIgnoringModifiers?.lowercased() == "a" {
                    self.requestSelectAll()
                    self.suppressCommandReleaseAfterSelectAll = true
                    return nil
                }

            case .flagsChanged:
                if self.suppressCommandReleaseAfterSelectAll,
                   !event.modifierFlags.contains(.command) {
                    self.suppressCommandReleaseAfterSelectAll = false
                    return nil
                }

            default:
                break
            }

            return event
        }
    }
}
