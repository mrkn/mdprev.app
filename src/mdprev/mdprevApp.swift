import AppKit
import Combine
import SwiftUI

struct PreviewWindowPayload: Hashable, Codable {
    private static let cascadeOffsetX: CGFloat = 24
    private static let cascadeOffsetY: CGFloat = 24

    let id: UUID
    let filePath: String?
    let preferredWindowOriginX: CGFloat?
    let preferredWindowOriginY: CGFloat?

    init(fileURL: URL?, sourceWindowFrame: CGRect? = nil) {
        self.id = UUID()
        self.filePath = fileURL?.standardizedFileURL.path

        if let sourceWindowFrame {
            preferredWindowOriginX = sourceWindowFrame.origin.x + Self.cascadeOffsetX
            preferredWindowOriginY = sourceWindowFrame.origin.y - Self.cascadeOffsetY
        } else {
            preferredWindowOriginX = nil
            preferredWindowOriginY = nil
        }
    }

    var fileURL: URL? {
        guard let filePath else {
            return nil
        }

        return URL(fileURLWithPath: filePath).standardizedFileURL
    }

    var preferredWindowOrigin: CGPoint? {
        guard let preferredWindowOriginX, let preferredWindowOriginY else {
            return nil
        }

        return CGPoint(x: preferredWindowOriginX, y: preferredWindowOriginY)
    }
}

private struct PreviewWindowRootView: View {
    @StateObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    init(initialFileURL: URL?, initialWindowOrigin: CGPoint?, recentFilesStore: RecentFilesStore) {
        _model = StateObject(
            wrappedValue: AppModel(
                recentFilesStore: recentFilesStore,
                initialFileURL: initialFileURL,
                initialWindowOrigin: initialWindowOrigin
            )
        )
    }

    var body: some View {
        ContentView(model: model)
            .focusedSceneObject(model)
            .frame(minWidth: 720, minHeight: 500)
            .onOpenURL { url in
                guard url.isFileURL else {
                    return
                }

                model.openFile(url.standardizedFileURL)
            }
            .task {
                consumePendingOpenFileIfNeeded(requirePreferredConsumer: true)
            }
            .onReceive(AppOpenFileQueue.shared.publisher) { _ in
                consumePendingOpenFileIfNeeded(requirePreferredConsumer: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                consumePendingOpenFileIfNeeded(requirePreferredConsumer: true)
            }
    }

    @MainActor
    private func consumePendingOpenFileIfNeeded(requirePreferredConsumer: Bool) {
        if requirePreferredConsumer && !model.isPreferredAppOpenFileConsumer {
            return
        }

        let fileURLs = AppOpenFileQueue.shared.dequeueAll()
        guard !fileURLs.isEmpty else {
            return
        }

        model.openFile(fileURLs[0])

        guard fileURLs.count > 1 else {
            return
        }

        let sourceWindowFrame = model.windowFrame ?? NSApp.keyWindow?.frame ?? NSApp.mainWindow?.frame
        for fileURL in fileURLs.dropFirst() {
            openWindow(value: PreviewWindowPayload(fileURL: fileURL, sourceWindowFrame: sourceWindowFrame))
        }
    }
}

private struct MDPrevCommands: Commands {
    @ObservedObject var recentFilesStore: RecentFilesStore

    @FocusedObject private var focusedModel: AppModel?
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") {
                openNewTab()
            }
            .keyboardShortcut("t", modifiers: [.command])

            Button("Open Markdown File...") {
                if let focusedModel {
                    focusedModel.requestFileOpen()
                } else if let fileURL = AppModel.chooseFileURL() {
                    openFileInNewWindow(fileURL)
                }
            }
            .keyboardShortcut("o", modifiers: [.command])

            Menu("Open Recent") {
                if recentFilesStore.fileURLs.isEmpty {
                    Button("No Recent Files") {}
                        .disabled(true)
                } else {
                    ForEach(recentFilesStore.fileURLs, id: \.path) { fileURL in
                        Button(fileURL.lastPathComponent) {
                            openRecentFile(fileURL)
                        }
                        .help(fileURL.path)
                    }

                    Divider()

                    Button("Clear Menu") {
                        recentFilesStore.clear()
                    }
                }
            }

            Button("Reload") {
                focusedModel?.reload()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(focusedModel?.selectedFileURL == nil)
        }

        CommandGroup(replacing: .textEditing) {
            Button("Select All") {
                focusedModel?.requestSelectAll()
            }
            .keyboardShortcut("a", modifiers: [.command])
            .disabled(focusedModel == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("Make Text Bigger") {
                focusedModel?.increaseBaseFontSize()
            }
            .keyboardShortcut("=", modifiers: [.command])
            .disabled(
                focusedModel == nil ||
                focusedModel?.baseFontSize == AppModel.baseFontSizeRange.upperBound
            )

            Button("Make Text Smaller") {
                focusedModel?.decreaseBaseFontSize()
            }
            .keyboardShortcut("-", modifiers: [.command])
            .disabled(
                focusedModel == nil ||
                focusedModel?.baseFontSize == AppModel.baseFontSizeRange.lowerBound
            )

            Divider()

            Button("Actual Size") {
                focusedModel?.resetBaseFontSize()
            }
            .keyboardShortcut("0", modifiers: [.command])
            .disabled(
                focusedModel == nil ||
                focusedModel?.baseFontSize == AppModel.defaultBaseFontSize
            )

            Divider()

            Menu("Theme") {
                ForEach(PreviewTheme.allCases, id: \.self) { theme in
                    Button(themeMenuTitle(for: theme)) {
                        focusedModel?.setPreviewTheme(theme)
                    }
                    .disabled(focusedModel == nil)
                }
            }

            Menu("Syntax Highlight") {
                Button(syntaxHighlightDisabledMenuTitle()) {
                    focusedModel?.setSyntaxHighlightTheme(.disabled)
                }
                .disabled(focusedModel == nil)

                Button(syntaxHighlightFollowThemeMenuTitle()) {
                    focusedModel?.setSyntaxHighlightTheme(.followPreview)
                }
                .disabled(focusedModel == nil)

                Menu("Color Theme") {
                    ForEach(syntaxHighlightThemeMenuModel.sections, id: \.letter) { section in
                        Menu(section.letter) {
                            ForEach(section.base16Subsections, id: \.letter) { subsection in
                                Menu("Base16 / \(subsection.letter)") {
                                    ForEach(subsection.themes, id: \.self) { theme in
                                        Button(codeThemeMenuTitle(for: theme)) {
                                            focusedModel?.setSyntaxHighlightTheme(theme)
                                        }
                                        .disabled(focusedModel == nil)
                                    }
                                }
                            }

                            ForEach(section.standaloneThemes, id: \.self) { theme in
                                Button(codeThemeMenuTitle(for: theme)) {
                                    focusedModel?.setSyntaxHighlightTheme(theme)
                                }
                                .disabled(focusedModel == nil)
                            }
                        }
                    }
                }
                .disabled(focusedModel == nil)
            }
        }
    }

    private func themeMenuTitle(for theme: PreviewTheme) -> String {
        if focusedModel?.previewTheme == theme {
            return "✓ \(theme.displayName)"
        }

        return theme.displayName
    }

    private func codeThemeMenuTitle(for theme: SyntaxHighlightTheme) -> String {
        if focusedModel?.syntaxHighlightTheme == theme {
            return "✓ \(theme.displayName)"
        }

        return theme.displayName
    }

    private func syntaxHighlightDisabledMenuTitle() -> String {
        if focusedModel?.syntaxHighlightTheme.isDisabled == true {
            return "✓ Disabled"
        }

        return "Disabled"
    }

    private func syntaxHighlightFollowThemeMenuTitle() -> String {
        if focusedModel?.syntaxHighlightTheme.isFollowPreview == true {
            return "✓ Follow Theme"
        }

        return "Follow Theme"
    }

    private var syntaxHighlightThemeMenuModel: SyntaxHighlightThemeMenuModel {
        SyntaxHighlightThemeMenuModel()
    }

    private func openRecentFile(_ fileURL: URL) {
        let action = RecentFileOpenAction.from(
            modifierFlags: NSEvent.modifierFlags,
            hasFocusedModel: focusedModel != nil
        )

        switch action {
        case .openInFocusedWindow:
            focusedModel?.openRecentFile(fileURL)

        case .openInNewWindow:
            openFileInNewWindow(fileURL)
        }
    }

    private func openEmptyWindow() {
        let sourceWindowFrame = focusedModel?.windowFrame ?? NSApp.keyWindow?.frame ?? NSApp.mainWindow?.frame
        openWindow(value: PreviewWindowPayload(fileURL: nil, sourceWindowFrame: sourceWindowFrame))
    }

    private func openFileInNewWindow(_ fileURL: URL) {
        let sourceWindowFrame = focusedModel?.windowFrame ?? NSApp.keyWindow?.frame ?? NSApp.mainWindow?.frame
        openWindow(value: PreviewWindowPayload(fileURL: fileURL, sourceWindowFrame: sourceWindowFrame))
    }

    private func openNewTab() {
        if let sourceWindow = NSApp.keyWindow ?? NSApp.mainWindow {
            WindowTabbingCoordinator.shared.requestTab(from: sourceWindow)
        }
        openEmptyWindow()
    }
}

@main
struct MDPrevApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var recentFilesStore = RecentFilesStore()

    var body: some Scene {
        WindowGroup {
            PreviewWindowRootView(
                initialFileURL: nil,
                initialWindowOrigin: nil,
                recentFilesStore: recentFilesStore
            )
        }
        .windowStyle(.titleBar)
        .commands {
            MDPrevCommands(recentFilesStore: recentFilesStore)
        }

        WindowGroup(for: PreviewWindowPayload.self) { $payload in
            PreviewWindowRootView(
                initialFileURL: payload?.fileURL,
                initialWindowOrigin: payload?.preferredWindowOrigin,
                recentFilesStore: recentFilesStore
            )
        }
        .windowStyle(.titleBar)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let fileURL = URL(fileURLWithPath: filename).standardizedFileURL
        AppOpenFileQueue.shared.enqueue([fileURL])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let fileURLs = filenames.map { URL(fileURLWithPath: $0).standardizedFileURL }
        AppOpenFileQueue.shared.enqueue(fileURLs)
        sender.reply(toOpenOrPrint: .success)
    }
}

@MainActor
private final class AppOpenFileQueue {
    static let shared = AppOpenFileQueue()

    private let eventSubject = PassthroughSubject<Void, Never>()
    private var queue: [URL] = []

    var publisher: AnyPublisher<Void, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    func enqueue(_ urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        queue.append(contentsOf: urls)
        eventSubject.send()
    }

    func dequeueAll() -> [URL] {
        guard !queue.isEmpty else {
            return []
        }

        let queued = queue
        queue.removeAll(keepingCapacity: true)
        return queued
    }
}
