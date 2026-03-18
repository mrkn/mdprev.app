import XCTest
@testable import mdprev

final class SyntaxHighlightSettingsViewTests: XCTestCase {
    func testQuickLookPreviewExtensionSettingsDestinationsPreferTheSpecificPaneFirst() {
        let urls = QuickLookPreviewExtensionSettingsDestination.urls.map(\.absoluteString)

        XCTAssertEqual(
            urls,
            [
                "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.quicklook.preview",
                "x-apple.systempreferences:com.apple.ExtensionsPreferences",
                "x-apple.systempreferences:com.apple.LoginItems-Settings.extension?ExtensionItems"
            ]
        )
    }
}
