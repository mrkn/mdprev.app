import XCTest
@testable import mdprev

final class ExternalURLPromptBuilderTests: XCTestCase {
    func testBuildIncludesRedirectWarningAndLocation() {
        let url = URL(string: "https://example.com/start")!
        let inspection = ExternalURLInspection(
            kind: .response(statusCode: 200, redirectLocation: "https://example.com/final")
        )

        let prompt = ExternalURLPromptBuilder.build(url: url, inspection: inspection)

        XCTAssertEqual(prompt.messageText, "Open External Link?")
        XCTAssertTrue(prompt.showsWarningStyle)
        XCTAssertTrue(prompt.informativeText.contains("URL:"))
        XCTAssertTrue(prompt.informativeText.contains("https://example.com/start"))
        XCTAssertTrue(prompt.informativeText.contains("Warning: This URL redirects."))
        XCTAssertTrue(prompt.informativeText.contains("Location: https://example.com/final"))
    }

    func testBuildWithSuccessfulHeadWithoutRedirectUsesInformationalStyle() {
        let url = URL(string: "https://example.com/ok")!
        let inspection = ExternalURLInspection(kind: .response(statusCode: 200, redirectLocation: nil))

        let prompt = ExternalURLPromptBuilder.build(url: url, inspection: inspection)

        XCTAssertFalse(prompt.showsWarningStyle)
        XCTAssertTrue(prompt.informativeText.contains("HEAD status: 200"))
        XCTAssertFalse(prompt.informativeText.contains("Warning: This URL redirects."))
    }

    func testBuildWithFailedHeadUsesWarningStyle() {
        let url = URL(string: "https://example.com/fail")!
        let inspection = ExternalURLInspection(kind: .failed("timed out"))

        let prompt = ExternalURLPromptBuilder.build(url: url, inspection: inspection)

        XCTAssertTrue(prompt.showsWarningStyle)
        XCTAssertTrue(prompt.informativeText.contains("HEAD request failed: timed out"))
    }
}
