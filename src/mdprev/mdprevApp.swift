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
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
}
