import XCTest
@testable import mdprev

@MainActor
final class AppModelFileOpenServiceTests: XCTestCase {
    func testRequestFileOpenUsesInjectedFileOpenService() {
        let context = TestContext()
        let fileURL = URL(fileURLWithPath: "/tmp/request-open.md").standardizedFileURL
        context.fileOpenService.chooseFileURLResult = fileURL
        context.fileOpenService.existingPaths.insert(fileURL.path)
        context.fileOpenService.markdownByPath[fileURL.path] = "# Request Open"

        let model = context.makeModel()
        model.requestFileOpen()

        XCTAssertEqual(model.selectedFileURL, fileURL)
        XCTAssertTrue(context.recentFilesStore.fileURLs.contains(fileURL))
    }

    func testOpenFileSkipsRecentRecordingWhenFileServiceReportsMissing() {
        let context = TestContext()
        let fileURL = URL(fileURLWithPath: "/tmp/missing.md").standardizedFileURL
        context.fileOpenService.markdownByPath[fileURL.path] = "# Missing"

        let model = context.makeModel()
        model.openFile(fileURL)

        XCTAssertEqual(model.selectedFileURL, fileURL)
        XCTAssertFalse(context.recentFilesStore.fileURLs.contains(fileURL))
    }

    private final class StubFileOpenService: FileOpenServicing {
        var chooseFileURLResult: URL?
        var existingPaths: Set<String> = []
        var markdownByPath: [String: String] = [:]

        func chooseFileURL() -> URL? {
            chooseFileURLResult
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

    @MainActor
    private final class TestContext {
        let userDefaultsSuite = "AppModelFileOpenServiceTests-\(UUID().uuidString)"
        let fileOpenService = StubFileOpenService()
        let userDefaults: UserDefaults
        let recentFilesStore: RecentFilesStore

        init() {
            userDefaults = UserDefaults(suiteName: userDefaultsSuite) ?? .standard
            userDefaults.removePersistentDomain(forName: userDefaultsSuite)
            recentFilesStore = RecentFilesStore(
                userDefaults: userDefaults,
                defaultsKey: "recent.files.tests.file-open-service",
                maxEntries: 10
            )
        }

        func makeModel() -> AppModel {
            AppModel(
                fileOpenService: fileOpenService,
                externalURLService: StubExternalURLService(),
                userDefaults: userDefaults,
                recentFilesStore: recentFilesStore
            )
        }
    }
}
