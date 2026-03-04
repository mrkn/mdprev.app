import AppKit
import Foundation

struct ExternalURLHandlingResult {
    let statusMessage: String
    let shouldBeep: Bool
}

@MainActor
protocol ExternalURLServicing {
    func handle(_ url: URL) async -> ExternalURLHandlingResult
}

@MainActor
final class ExternalURLService: ExternalURLServicing {
    func handle(_ url: URL) async -> ExternalURLHandlingResult {
        let inspection = await ExternalURLInspector.inspect(url)
        let prompt = ExternalURLPromptBuilder.build(url: url, inspection: inspection)

        let alert = NSAlert()
        alert.messageText = prompt.messageText
        alert.informativeText = prompt.informativeText
        alert.alertStyle = prompt.showsWarningStyle ? .warning : .informational
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return ExternalURLHandlingResult(
                statusMessage: "Cancelled opening external URL.",
                shouldBeep: false
            )
        }

        do {
            try ExternalURLInspector.openWithOpenCommand(url)
            return ExternalURLHandlingResult(
                statusMessage: "Opened external URL: \(url.absoluteString)",
                shouldBeep: false
            )
        } catch {
            return ExternalURLHandlingResult(
                statusMessage: "Failed to open external URL: \(error.localizedDescription)",
                shouldBeep: true
            )
        }
    }
}
