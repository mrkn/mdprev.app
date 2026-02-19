import AppKit
import SwiftUI

@main
struct MDPrevApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 720, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Markdown File...") {
                    model.requestFileOpen()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Reload") {
                    model.reload()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(model.selectedFileURL == nil)
            }

            CommandGroup(replacing: .textEditing) {
                Button("Select All") {
                    model.requestSelectAll()
                }
                .keyboardShortcut("a", modifiers: [.command])
            }

            CommandMenu("View") {
                Button("Make Text Bigger") {
                    model.increaseBaseFontSize()
                }
                .keyboardShortcut("=", modifiers: [.command])
                .disabled(model.baseFontSize >= AppModel.baseFontSizeRange.upperBound)

                Button("Make Text Smaller") {
                    model.decreaseBaseFontSize()
                }
                .keyboardShortcut("-", modifiers: [.command])
                .disabled(model.baseFontSize <= AppModel.baseFontSizeRange.lowerBound)

                Divider()

                Button("Actual Size") {
                    model.resetBaseFontSize()
                }
                .keyboardShortcut("0", modifiers: [.command])
                .disabled(model.baseFontSize == AppModel.defaultBaseFontSize)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
}
