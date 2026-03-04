import AppKit
import SwiftUI

@MainActor
final class WindowBehaviorController: NSObject {
    private weak var window: NSWindow?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func attach(window: NSWindow, preferredInitialOrigin: CGPoint? = nil) {
        guard self.window !== window else {
            return
        }

        NotificationCenter.default.removeObserver(self)

        self.window = window
        configure(window)
        applyInitialOrigin(preferredInitialOrigin, to: window)
        installObservers(for: window)
        updateTrafficLightAppearance()
        DispatchQueue.main.async { [weak window] in
            guard let window else {
                return
            }

            WindowTabbingCoordinator.shared.consumePendingRequest(with: window)
        }
    }

    private func applyInitialOrigin(_ origin: CGPoint?, to window: NSWindow) {
        guard let origin else {
            return
        }

        DispatchQueue.main.async { [weak window] in
            guard let window else {
                return
            }

            let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame
            let targetOrigin = Self.clampedOrigin(origin, forWindowFrame: window.frame, in: visibleFrame)
            window.setFrameOrigin(targetOrigin)
        }
    }

    private static func clampedOrigin(_ origin: CGPoint, forWindowFrame frame: CGRect, in visibleFrame: CGRect?) -> CGPoint {
        guard let visibleFrame else {
            return origin
        }

        let minX = visibleFrame.minX
        let maxX = max(minX, visibleFrame.maxX - frame.width)
        let minY = visibleFrame.minY
        let maxY = max(minY, visibleFrame.maxY - frame.height)

        return CGPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }

    private func configure(_ window: NSWindow) {
        window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "mdprev.preview"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        window.showsResizeIndicator = true

        if let contentView = window.contentView {
            window.invalidateCursorRects(for: contentView)
        }
    }

    private func installObservers(for window: NSWindow) {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleWindowOrAppStateChange), name: NSWindow.didBecomeKeyNotification, object: window)
        center.addObserver(self, selector: #selector(handleWindowOrAppStateChange), name: NSWindow.didResignKeyNotification, object: window)
        center.addObserver(self, selector: #selector(handleWindowOrAppStateChange), name: NSWindow.didResizeNotification, object: window)
        center.addObserver(self, selector: #selector(handleWindowOrAppStateChange), name: NSApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(handleWindowOrAppStateChange), name: NSApplication.didResignActiveNotification, object: nil)
    }

    @objc
    private func handleWindowOrAppStateChange(_ notification: Notification) {
        if let contentView = window?.contentView {
            window?.invalidateCursorRects(for: contentView)
        }
        updateTrafficLightAppearance()
    }

    private func updateTrafficLightAppearance() {
        guard let window else {
            return
        }

        let active = NSApp.isActive && window.isKeyWindow
        let alpha: CGFloat = active ? 1.0 : 0.45
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]

        for type in buttonTypes {
            window.standardWindowButton(type)?.alphaValue = alpha
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
