import XCTest
@testable import mdprev

@MainActor
final class AppModelWindowTitleTests: XCTestCase {
    func testWindowTitleDefaultsToAppNameWhenNoFileIsSelected() {
        let model = AppModel()

        XCTAssertEqual(model.windowTitle, "mdprev")
    }

    func testWindowTitleUsesSelectedFileName() {
        let fileURL = URL(fileURLWithPath: "/tmp/example.md").standardizedFileURL
        let context = TestContext(fileURL: fileURL)
        let model = context.makeModel()

        model.openFile(fileURL)

        XCTAssertEqual(model.windowTitle, "example.md")
    }
}

@MainActor
private final class TestContext {
    let userDefaultsSuite = "AppModelWindowTitleTests-\(UUID().uuidString)"
    let fileOpenService = StubFileOpenService()
    let userDefaults: UserDefaults
    let recentFilesStore: RecentFilesStore

    init(fileURL: URL) {
        userDefaults = UserDefaults(suiteName: userDefaultsSuite) ?? .standard
        userDefaults.removePersistentDomain(forName: userDefaultsSuite)
        recentFilesStore = RecentFilesStore(
            userDefaults: userDefaults,
            defaultsKey: "recent.files.tests.window-title",
            maxEntries: 10
        )
        fileOpenService.existingPaths.insert(fileURL.path)
        fileOpenService.markdownByPath[fileURL.path] = "# Example"
    }

    func makeModel() -> AppModel {
        AppModel(
            fileOpenService: fileOpenService,
            externalURLService: StubExternalURLService(),
            syntaxHighlightSettingsStore: SyntaxHighlightSettingsStore(userDefaults: userDefaults),
            userDefaults: userDefaults,
            recentFilesStore: recentFilesStore
        )
    }
}

private final class StubFileOpenService: FileOpenServicing {
    var existingPaths: Set<String> = []
    var markdownByPath: [String: String] = [:]

    func chooseFileURL() -> URL? {
        nil
    }

    func readMarkdown(from fileURL: URL) throws -> String {
        markdownByPath[fileURL.standardizedFileURL.path] ?? ""
    }

    func fileExists(at fileURL: URL) -> Bool {
        existingPaths.contains(fileURL.standardizedFileURL.path)
    }
}

private struct StubExternalURLService: ExternalURLServicing {
    func handle(_ url: URL) async -> ExternalURLHandlingResult {
        ExternalURLHandlingResult(statusMessage: "unused", shouldBeep: false)
    }
}
