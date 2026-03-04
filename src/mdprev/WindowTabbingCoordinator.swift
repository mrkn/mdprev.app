import AppKit

@MainActor
final class WindowTabbingCoordinator {
    static let shared = WindowTabbingCoordinator()

    private weak var sourceWindow: NSWindow?
    private var hasPendingRequest = false

    private init() {}

    func requestTab(from sourceWindow: NSWindow) {
        self.sourceWindow = sourceWindow
        hasPendingRequest = true
    }

    func consumePendingRequest(with newWindow: NSWindow) {
        guard hasPendingRequest else {
            return
        }

        defer {
            hasPendingRequest = false
            sourceWindow = nil
        }

        guard let sourceWindow,
              sourceWindow !== newWindow else {
            return
        }

        sourceWindow.tabbingMode = .preferred
        newWindow.tabbingMode = .preferred

        let alreadyTabbed = sourceWindow.tabbedWindows?.contains(where: { $0 === newWindow }) == true
        if !alreadyTabbed {
            sourceWindow.addTabbedWindow(newWindow, ordered: .above)
        }

        sourceWindow.tabGroup?.selectedWindow = newWindow
        newWindow.makeKeyAndOrderFront(nil)
    }
}
