import Foundation
import XCTest
@testable import mdprev

final class FileSnapshotTests: XCTestCase {
    func testCaptureForExistingFile() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".md")

        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let snapshot = FileSnapshot.capture(at: fileURL)

        XCTAssertTrue(snapshot.exists)
        XCTAssertEqual(snapshot.size, 5)
        XCTAssertNotNil(snapshot.modifiedAt)
    }

    func testCaptureForMissingFile() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")

        let snapshot = FileSnapshot.capture(at: fileURL)

        XCTAssertFalse(snapshot.exists)
        XCTAssertNil(snapshot.size)
        XCTAssertNil(snapshot.modifiedAt)
    }
}
