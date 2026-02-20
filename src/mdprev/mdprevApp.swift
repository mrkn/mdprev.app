import AppKit
import SwiftUI

private struct PreviewWindowPayload: Hashable, Codable {
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
    }
}

private struct MDPrevCommands: Commands {
    @ObservedObject var recentFilesStore: RecentFilesStore

    @FocusedObject private var focusedModel: AppModel?
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
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

        CommandMenu("View") {
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
        }
    }

    private func openRecentFile(_ fileURL: URL) {
        if let focusedModel {
            focusedModel.openRecentFile(fileURL)
            if NSEvent.modifierFlags.contains(.option) {
                openEmptyWindow()
            }
            return
        }

        if NSEvent.modifierFlags.contains(.option) {
            openEmptyWindow()
            return
        }

        openFileInNewWindow(fileURL)
    }

    private func openEmptyWindow() {
        let sourceWindowFrame = focusedModel?.windowFrame ?? NSApp.keyWindow?.frame ?? NSApp.mainWindow?.frame
        openWindow(value: PreviewWindowPayload(fileURL: nil, sourceWindowFrame: sourceWindowFrame))
    }

    private func openFileInNewWindow(_ fileURL: URL) {
        let sourceWindowFrame = focusedModel?.windowFrame ?? NSApp.keyWindow?.frame ?? NSApp.mainWindow?.frame
        openWindow(value: PreviewWindowPayload(fileURL: fileURL, sourceWindowFrame: sourceWindowFrame))
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
}
