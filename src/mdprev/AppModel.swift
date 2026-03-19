import AppKit
import Combine
import Foundation
import MDPrevRendering

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

            userDefaults.set(previewTheme.rawValue, forKey: SharedPreviewSettings.previewThemeDefaultsKey)
            reload()
        }
    }
    @Published var syntaxHighlightTheme: SyntaxHighlightTheme {
        didSet {
            guard oldValue != syntaxHighlightTheme else {
                return
            }

            userDefaults.set(syntaxHighlightTheme.rawValue, forKey: SharedPreviewSettings.syntaxThemeDefaultsKey)
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

            userDefaults.set(baseFontSize, forKey: SharedPreviewSettings.baseFontSizeDefaultsKey)
            reload()
        }
    }
    @Published var lastReloadDate: Date?
    @Published private(set) var selectAllRequestID: UInt = 0

    private let renderer: MarkdownRenderer
    private let fileOpenService: any FileOpenServicing
    private let externalURLService: any ExternalURLServicing
    private let syntaxHighlightSettingsStore: SyntaxHighlightSettingsStore
    private let userDefaults: UserDefaults
    private let recentFilesStore: RecentFilesStore
    private var initialWindowOrigin: CGPoint?
    private var watcher: FileWatcher?
    private weak var attachedWindow: NSWindow?
    private let windowBehaviorController = WindowBehaviorController()
    private var windowCloseObserver: NSObjectProtocol?
    private var recentFilesObserver: AnyCancellable?
    private var syntaxHighlightSettingsObserver: AnyCancellable?

    init(
        renderer: MarkdownRenderer = MarkdownRenderer(),
        fileOpenService: any FileOpenServicing = FileOpenService(),
        externalURLService: any ExternalURLServicing = ExternalURLService(),
        syntaxHighlightSettingsStore: SyntaxHighlightSettingsStore = SyntaxHighlightSettingsStore(),
        userDefaults: UserDefaults = SharedPreviewSettings.userDefaults(),
        recentFilesStore: RecentFilesStore = RecentFilesStore(),
        initialFileURL: URL? = nil,
        initialWindowOrigin: CGPoint? = nil
    ) {
        self.renderer = renderer
        self.fileOpenService = fileOpenService
        self.externalURLService = externalURLService
        self.syntaxHighlightSettingsStore = syntaxHighlightSettingsStore
        self.userDefaults = userDefaults
        self.recentFilesStore = recentFilesStore
        self.initialWindowOrigin = initialWindowOrigin

        let initialBaseFontSize: Double
        if let storedValue = userDefaults.object(forKey: SharedPreviewSettings.baseFontSizeDefaultsKey) as? NSNumber {
            initialBaseFontSize = Self.clampBaseFontSize(storedValue.doubleValue)
        } else {
            initialBaseFontSize = Self.defaultBaseFontSize
        }
        let initialPreviewTheme = PreviewTheme(
            storedValue: userDefaults.string(forKey: SharedPreviewSettings.previewThemeDefaultsKey)
        )
        let initialSyntaxTheme = SyntaxHighlightTheme(
            storedValue: userDefaults.string(forKey: SharedPreviewSettings.syntaxThemeDefaultsKey)
        )

        self.previewTheme = initialPreviewTheme
        self.syntaxHighlightTheme = initialSyntaxTheme
        self.baseFontSize = initialBaseFontSize

        self.renderedHTML = MarkdownRenderer.placeholderHTML(
            Self.noFileSelectedMessage,
            baseFontSize: initialBaseFontSize,
            theme: initialPreviewTheme,
            syntaxTheme: initialSyntaxTheme,
            followThemeLightIdentifier: syntaxHighlightSettingsStore.followThemeLightIdentifier,
            followThemeDarkIdentifier: syntaxHighlightSettingsStore.followThemeDarkIdentifier,
            followThemeSepiaIdentifier: syntaxHighlightSettingsStore.effectiveFollowThemeSepiaIdentifier,
            recentFiles: recentFilesStore.fileURLs
        )

        observeRecentFiles()
        observeSyntaxHighlightSettings()

        if let initialFileURL {
            openFile(initialFileURL)
        }
    }

    func requestFileOpen() {
        guard let fileURL = fileOpenService.chooseFileURL() else {
            return
        }

        openFile(fileURL)
    }

    static func chooseFileURL() -> URL? {
        FileOpenService().chooseFileURL()
    }

    func openFile(_ fileURL: URL) {
        let normalizedFileURL = fileURL.standardizedFileURL
        selectedFileURL = normalizedFileURL
        updateWindowTitle()
        reload()
        configureWatcher()

        if fileOpenService.fileExists(at: normalizedFileURL) {
            recentFilesStore.record(normalizedFileURL)
        }
    }

    func openRecentFile(_ fileURL: URL) {
        let normalizedURL = fileURL.standardizedFileURL
        guard fileOpenService.fileExists(at: normalizedURL) else {
            recentFilesStore.remove(normalizedURL)
            statusMessage = "File not found: \(normalizedURL.lastPathComponent)"
            NSSound.beep()
            renderedHTML = MarkdownRenderer.placeholderHTML(
                Self.noFileSelectedMessage,
                baseFontSize: baseFontSize,
                theme: previewTheme,
                syntaxTheme: syntaxHighlightTheme,
                followThemeLightIdentifier: followThemeLightIdentifier,
                followThemeDarkIdentifier: followThemeDarkIdentifier,
                followThemeSepiaIdentifier: followThemeSepiaIdentifier,
                recentFiles: recentFilesStore.fileURLs
            )
            lastReloadDate = nil
            return
        }

        openFile(normalizedURL)
    }

    func handleActivatedLocalFileLink(
        _ fileURL: URL,
        disposition: LinkOpenDisposition,
        openMarkdownInNewTab: (URL) -> Void,
        openMarkdownInNewWindow: (URL) -> Void
    ) {
        switch LocalFileLinkResolver.resolve(fileURL) {
        case .openMarkdown(let markdownURL):
            switch disposition {
            case .currentTab:
                openFile(markdownURL)
            case .newTab:
                openMarkdownInNewTab(markdownURL)
            case .newWindow:
                openMarkdownInNewWindow(markdownURL)
            }

        case .revealParentDirectory(let directoryURL):
            statusMessage = "Opened folder for \(fileURL.lastPathComponent)"
            NSWorkspace.shared.open(directoryURL)

        case .missingFile(let missingURL):
            statusMessage = "Linked file not found: \(missingURL.lastPathComponent)"
            NSSound.beep()
        }
    }

    func handleActivatedExternalURL(_ url: URL) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let result = await externalURLService.handle(url)
            statusMessage = result.statusMessage
            if result.shouldBeep {
                NSSound.beep()
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
        updateWindowTitle()
        observeWindowClose(for: window)
    }

    var windowFrame: CGRect? {
        attachedWindow?.frame
    }

    var windowTitle: String {
        selectedFileURL?.lastPathComponent ?? Self.defaultWindowTitle
    }

    var isPreferredAppOpenFileConsumer: Bool {
        let visibleWindowNumbers = NSApp.windows
            .filter { $0.isVisible && !$0.isMiniaturized }
            .map(\.windowNumber)

        return AppOpenFileConsumerSelector.isPreferred(
            candidateWindowNumber: attachedWindow?.windowNumber,
            keyWindowNumber: NSApp.keyWindow?.windowNumber,
            mainWindowNumber: NSApp.mainWindow?.windowNumber,
            orderedWindowNumbers: visibleWindowNumbers
        )
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

    func setSyntaxHighlightTheme(_ theme: SyntaxHighlightTheme) {
        syntaxHighlightTheme = theme
    }

    func reload() {
        guard let fileURL = selectedFileURL else {
            renderedHTML = MarkdownRenderer.placeholderHTML(
                Self.noFileSelectedMessage,
                baseFontSize: baseFontSize,
                theme: previewTheme,
                syntaxTheme: syntaxHighlightTheme,
                followThemeLightIdentifier: followThemeLightIdentifier,
                followThemeDarkIdentifier: followThemeDarkIdentifier,
                followThemeSepiaIdentifier: followThemeSepiaIdentifier,
                recentFiles: recentFilesStore.fileURLs
            )
            statusMessage = "No file selected."
            lastReloadDate = nil
            return
        }

        do {
            let markdown = try fileOpenService.readMarkdown(from: fileURL)
            renderedHTML = renderer.renderHTML(
                markdown,
                baseFontSize: baseFontSize,
                theme: previewTheme,
                syntaxTheme: syntaxHighlightTheme,
                followThemeLightIdentifier: followThemeLightIdentifier,
                followThemeDarkIdentifier: followThemeDarkIdentifier,
                followThemeSepiaIdentifier: followThemeSepiaIdentifier
            )
            statusMessage = "Previewing \(fileURL.lastPathComponent)"
            lastReloadDate = Date()
        } catch {
            renderedHTML = MarkdownRenderer.placeholderHTML(
                "Failed to load file.",
                baseFontSize: baseFontSize,
                theme: previewTheme,
                syntaxTheme: syntaxHighlightTheme,
                followThemeLightIdentifier: followThemeLightIdentifier,
                followThemeDarkIdentifier: followThemeDarkIdentifier,
                followThemeSepiaIdentifier: followThemeSepiaIdentifier
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

    private static let noFileSelectedMessage = "Open a Markdown file to start previewing."
    private static let defaultWindowTitle = "mdprev"

    private static func clampBaseFontSize(_ value: Double) -> Double {
        min(max(value, baseFontSizeRange.lowerBound), baseFontSizeRange.upperBound)
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

    private func observeSyntaxHighlightSettings() {
        syntaxHighlightSettingsObserver = Publishers.CombineLatest4(
            syntaxHighlightSettingsStore.$followThemeLightIdentifier,
            syntaxHighlightSettingsStore.$followThemeDarkIdentifier,
            syntaxHighlightSettingsStore.$followThemeSepiaMode,
            syntaxHighlightSettingsStore.$followThemeSepiaIdentifier
        ).sink { [weak self] _, _, _, _ in
            guard let self else {
                return
            }

            if self.syntaxHighlightTheme.isFollowPreview {
                self.reload()
            }
        }
    }

    private func updateWindowTitle() {
        guard let attachedWindow else {
            return
        }

        attachedWindow.title = windowTitle

        if let selectedFileURL {
            attachedWindow.representedURL = selectedFileURL
        } else {
            attachedWindow.representedURL = nil
        }
    }

    private var followThemeLightIdentifier: String {
        syntaxHighlightSettingsStore.followThemeLightIdentifier
    }

    private var followThemeDarkIdentifier: String {
        syntaxHighlightSettingsStore.followThemeDarkIdentifier
    }

    private var followThemeSepiaIdentifier: String {
        syntaxHighlightSettingsStore.effectiveFollowThemeSepiaIdentifier
    }
}
