import Foundation
import XCTest
@testable import mdprev

@MainActor
final class RecentFilesStoreTests: XCTestCase {
    func testRecordKeepsMostRecentOrderAndCapsEntries() {
        let defaults = makeIsolatedDefaults()
        let store = RecentFilesStore(userDefaults: defaults, defaultsKey: "recent.test", maxEntries: 3)

        let temp = FileManager.default.temporaryDirectory
        let a = temp.appendingPathComponent("a.md")
        let b = temp.appendingPathComponent("b.md")
        let c = temp.appendingPathComponent("c.md")
        let d = temp.appendingPathComponent("d.md")

        store.record(a)
        store.record(b)
        store.record(c)
        store.record(d)
        store.record(b)

        XCTAssertEqual(store.fileURLs.map(\.lastPathComponent), ["b.md", "d.md", "c.md"])
    }

    func testRecordPersistsAcrossInstances() {
        let defaults = makeIsolatedDefaults()
        let key = "recent.persist.test"
        let temp = FileManager.default.temporaryDirectory
        let fileURL = temp.appendingPathComponent("persist.md")

        do {
            let store = RecentFilesStore(userDefaults: defaults, defaultsKey: key, maxEntries: 10)
            store.record(fileURL)
        }

        let reloadedStore = RecentFilesStore(userDefaults: defaults, defaultsKey: key, maxEntries: 10)
        XCTAssertEqual(reloadedStore.fileURLs.map(\.path), [fileURL.standardizedFileURL.path])
    }

    func testLoadCapsEntriesToConfiguredMaximum() {
        let defaults = makeIsolatedDefaults()
        let key = "recent.load.cap.test"
        let temp = FileManager.default.temporaryDirectory
        let paths = (0..<12).map { index in
            temp.appendingPathComponent("cap-\(index).md").path
        }
        defaults.set(paths, forKey: key)

        let store = RecentFilesStore(userDefaults: defaults, defaultsKey: key, maxEntries: 10)

        XCTAssertEqual(store.fileURLs.count, 10)
        XCTAssertEqual(store.fileURLs.first?.lastPathComponent, "cap-0.md")
        XCTAssertEqual(store.fileURLs.last?.lastPathComponent, "cap-9.md")
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "mdprev.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
