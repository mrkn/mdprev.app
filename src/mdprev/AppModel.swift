import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    static let defaultBaseFontSize: Double = 16
    static let baseFontSizeRange: ClosedRange<Double> = 12...30

    @Published var selectedFileURL: URL?
    @Published var renderedHTML: String
    @Published var statusMessage = "No file selected."
    @Published var autoReloadEnabled = true {
        didSet {
            configureWatcher()
        }
    }
    @Published var previewTheme: PreviewTheme {
        didSet {
            guard oldValue != previewTheme else {
                return
            }

            userDefaults.set(previewTheme.rawValue, forKey: Self.previewThemeDefaultsKey)
            reload()
        }
    }
    @Published var baseFontSize: Double {
        didSet {
            let clamped = Self.clampBaseFontSize(baseFontSize)
            if clamped != baseFontSize {
                baseFontSize = clamped
                return
            }

            guard oldValue != baseFontSize else {
                return
            }

            userDefaults.set(baseFontSize, forKey: Self.baseFontSizeDefaultsKey)
            reload()
        }
    }
    @Published var lastReloadDate: Date?
    @Published private(set) var selectAllRequestID: UInt = 0

    private let renderer: MarkdownRenderer
    private let userDefaults: UserDefaults
    private let recentFilesStore: RecentFilesStore
    private var initialWindowOrigin: CGPoint?
    private var watcher: FileWatcher?
    private weak var attachedWindow: NSWindow?
    private let windowBehaviorController = WindowBehaviorController()
    private var keyboardMonitor: Any?
    private var windowCloseObserver: NSObjectProtocol?
    private var recentFilesObserver: AnyCancellable?
    private var suppressCommandReleaseAfterSelectAll = false

    init(
        renderer: MarkdownRenderer = MarkdownRenderer(),
        userDefaults: UserDefaults = .standard,
        recentFilesStore: RecentFilesStore = RecentFilesStore(),
        initialFileURL: URL? = nil,
        initialWindowOrigin: CGPoint? = nil
    ) {
        self.renderer = renderer
        self.userDefaults = userDefaults
        self.recentFilesStore = recentFilesStore
        self.initialWindowOrigin = initialWindowOrigin

        let initialBaseFontSize: Double
        if let storedValue = userDefaults.object(forKey: Self.baseFontSizeDefaultsKey) as? NSNumber {
            initialBaseFontSize = Self.clampBaseFontSize(storedValue.doubleValue)
        } else {
            initialBaseFontSize = Self.defaultBaseFontSize
        }
        let initialPreviewTheme = PreviewTheme(
            storedValue: userDefaults.string(forKey: Self.previewThemeDefaultsKey)
        )

        self.previewTheme = initialPreviewTheme
        self.baseFontSize = initialBaseFontSize

        self.renderedHTML = MarkdownRenderer.placeholderHTML(
            Self.noFileSelectedMessage,
            baseFontSize: initialBaseFontSize,
            theme: initialPreviewTheme,
            recentFiles: recentFilesStore.fileURLs
        )

        observeRecentFiles()

        if let initialFileURL {
            openFile(initialFileURL)
        }
    }

    func requestFileOpen() {
        guard let fileURL = Self.chooseFileURL() else {
            return
        }

        openFile(fileURL)
    }

    static func chooseFileURL() -> URL? {
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

    func openFile(_ fileURL: URL) {
        let normalizedFileURL = fileURL.standardizedFileURL
        selectedFileURL = normalizedFileURL
        reload()
        configureWatcher()

        if FileManager.default.fileExists(atPath: normalizedFileURL.path) {
            recentFilesStore.record(normalizedFileURL)
        }
    }

    func openRecentFile(_ fileURL: URL) {
        let normalizedURL = fileURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: normalizedURL.path) else {
            recentFilesStore.remove(normalizedURL)
            statusMessage = "File not found: \(normalizedURL.lastPathComponent)"
            NSSound.beep()
            renderedHTML = MarkdownRenderer.placeholderHTML(
                Self.noFileSelectedMessage,
                baseFontSize: baseFontSize,
                theme: previewTheme,
                recentFiles: recentFilesStore.fileURLs
            )
            lastReloadDate = nil
            return
        }

        openFile(normalizedURL)
    }

    func handleActivatedLocalFileLink(
        _ fileURL: URL,
        openMarkdownInNewWindow: (URL) -> Void
    ) {
        switch LocalFileLinkResolver.resolve(fileURL) {
        case .openMarkdownInNewWindow(let markdownURL):
            openMarkdownInNewWindow(markdownURL)

        case .revealParentDirectory(let directoryURL):
            statusMessage = "Opened folder for \(fileURL.lastPathComponent)"
            NSWorkspace.shared.open(directoryURL)

        case .missingFile(let missingURL):
            statusMessage = "Linked file not found: \(missingURL.lastPathComponent)"
            NSSound.beep()
        }
    }

    func handleActivatedExternalURL(_ url: URL) {
        Task { [weak self] in
            guard let self else {
                return
            }

            let inspection = await ExternalURLInspector.inspect(url)
            await MainActor.run {
                self.confirmAndOpenExternalURL(url, inspection: inspection)
            }
        }
    }

    func attachWindow(_ window: NSWindow) {
        guard attachedWindow !== window else {
            return
        }

        removeWindowCloseObserver()
        attachedWindow = window
        windowBehaviorController.attach(window: window, preferredInitialOrigin: initialWindowOrigin)
        initialWindowOrigin = nil
        installKeyboardMonitorIfNeeded()
        observeWindowClose(for: window)
    }

    var windowFrame: CGRect? {
        attachedWindow?.frame
    }

    func requestSelectAll() {
        selectAllRequestID &+= 1
    }

    func increaseBaseFontSize() {
        baseFontSize = min(baseFontSize + 1, Self.baseFontSizeRange.upperBound)
    }

    func decreaseBaseFontSize() {
        baseFontSize = max(baseFontSize - 1, Self.baseFontSizeRange.lowerBound)
    }

    func resetBaseFontSize() {
        baseFontSize = Self.defaultBaseFontSize
    }

    func setPreviewTheme(_ theme: PreviewTheme) {
        previewTheme = theme
    }

    func reload() {
        guard let fileURL = selectedFileURL else {
            renderedHTML = MarkdownRenderer.placeholderHTML(
                Self.noFileSelectedMessage,
                baseFontSize: baseFontSize,
                theme: previewTheme,
                recentFiles: recentFilesStore.fileURLs
            )
            statusMessage = "No file selected."
            lastReloadDate = nil
            return
        }

        do {
            let markdown = try String(contentsOf: fileURL, encoding: .utf8)
            renderedHTML = renderer.renderHTML(
                markdown,
                baseFontSize: baseFontSize,
                theme: previewTheme
            )
            statusMessage = "Previewing \(fileURL.lastPathComponent)"
            lastReloadDate = Date()
        } catch {
            renderedHTML = MarkdownRenderer.placeholderHTML(
                "Failed to load file.",
                baseFontSize: baseFontSize,
                theme: previewTheme
            )
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

    private static let baseFontSizeDefaultsKey = "preview.baseFontSize"
    private static let previewThemeDefaultsKey = "preview.theme"
    private static let noFileSelectedMessage = "Open a Markdown file to start previewing."

    private static func clampBaseFontSize(_ value: Double) -> Double {
        min(max(value, baseFontSizeRange.lowerBound), baseFontSizeRange.upperBound)
    }

    private func installKeyboardMonitorIfNeeded() {
        guard keyboardMonitor == nil else {
            return
        }

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else {
                return event
            }
            guard self.attachedWindow?.isKeyWindow == true else {
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

    private func removeKeyboardMonitor() {
        guard let keyboardMonitor else {
            return
        }

        NSEvent.removeMonitor(keyboardMonitor)
        self.keyboardMonitor = nil
    }

    private func observeWindowClose(for window: NSWindow) {
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWindowClosed()
            }
        }
    }

    private func removeWindowCloseObserver() {
        guard let windowCloseObserver else {
            return
        }

        NotificationCenter.default.removeObserver(windowCloseObserver)
        self.windowCloseObserver = nil
    }

    private func handleWindowClosed() {
        removeKeyboardMonitor()
        removeWindowCloseObserver()
        watcher?.stop()
        watcher = nil
        attachedWindow = nil
    }

    private func observeRecentFiles() {
        recentFilesObserver = recentFilesStore.$fileURLs.sink { [weak self] _ in
            guard let self else {
                return
            }

            if self.selectedFileURL == nil {
                self.reload()
            }
        }
    }

    private func confirmAndOpenExternalURL(_ url: URL, inspection: ExternalURLInspection) {
        let prompt = ExternalURLPromptBuilder.build(url: url, inspection: inspection)

        let alert = NSAlert()
        alert.messageText = prompt.messageText
        alert.informativeText = prompt.informativeText
        alert.alertStyle = prompt.showsWarningStyle ? .warning : .informational
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            statusMessage = "Cancelled opening external URL."
            return
        }

        do {
            try ExternalURLInspector.openWithOpenCommand(url)
            statusMessage = "Opened external URL: \(url.absoluteString)"
        } catch {
            statusMessage = "Failed to open external URL: \(error.localizedDescription)"
            NSSound.beep()
        }
    }
}
