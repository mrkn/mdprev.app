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
                consumePendingOpenFileIfNeeded()
            }
            .onReceive(AppOpenFileQueue.shared.publisher) { _ in
                consumePendingOpenFileIfNeeded()
            }
    }

    @MainActor
    private func consumePendingOpenFileIfNeeded() {
        guard let fileURL = AppOpenFileQueue.shared.dequeueNext() else {
            return
        }

        model.openFile(fileURL)
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
                    ForEach(syntaxHighlightThemeSections(), id: \.letter) { section in
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

    private func syntaxHighlightThemeSections() -> [SyntaxHighlightThemeSection] {
        let themes = SyntaxHighlightTheme.allCases
            .filter { !$0.isDisabled && !$0.isFollowPreview }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        let grouped = Dictionary(grouping: themes) { theme in
            firstLetter(for: theme.displayName)
        }

        return grouped
            .map { entry in
                makeSyntaxHighlightThemeSection(
                    letter: entry.key,
                    themes: entry.value
                )
            }
            .sorted { lhs, rhs in
                lhs.letter.localizedCaseInsensitiveCompare(rhs.letter) == .orderedAscending
            }
    }

    private func makeSyntaxHighlightThemeSection(
        letter: String,
        themes: [SyntaxHighlightTheme]
    ) -> SyntaxHighlightThemeSection {
        let base16Themes = themes
            .filter { $0.rawValue.hasPrefix("base16/") }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        let standaloneThemes = themes
            .filter { !$0.rawValue.hasPrefix("base16/") }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        let base16Grouped = Dictionary(grouping: base16Themes) { theme in
            base16ThemeGroupLetter(for: theme)
        }

        let base16Subsections = base16Grouped
            .map { entry in
                Base16ThemeSubsection(
                    letter: entry.key,
                    themes: entry.value.sorted { lhs, rhs in
                        lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                    }
                )
            }
            .sorted { lhs, rhs in
                lhs.letter.localizedCaseInsensitiveCompare(rhs.letter) == .orderedAscending
            }

        return SyntaxHighlightThemeSection(
            letter: letter,
            base16Subsections: base16Subsections,
            standaloneThemes: standaloneThemes
        )
    }

    private func base16ThemeGroupLetter(for theme: SyntaxHighlightTheme) -> String {
        guard theme.rawValue.hasPrefix("base16/") else {
            return "#"
        }

        let suffix = String(theme.rawValue.dropFirst("base16/".count))
        return firstLetter(for: suffix)
    }

    private func firstLetter(for title: String) -> String {
        guard let first = title.first else {
            return "#"
        }

        return String(first).uppercased()
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

    private struct SyntaxHighlightThemeSection {
        let letter: String
        let base16Subsections: [Base16ThemeSubsection]
        let standaloneThemes: [SyntaxHighlightTheme]
    }

    private struct Base16ThemeSubsection {
        let letter: String
        let themes: [SyntaxHighlightTheme]
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

    func dequeueNext() -> URL? {
        guard !queue.isEmpty else {
            return nil
        }

        return queue.removeFirst()
    }
}
