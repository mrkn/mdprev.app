import Foundation
import XCTest
@testable import mdprev

final class LocalFileLinkResolverTests: XCTestCase {
    func testResolveMarkdownFileAsOpenInNewWindow() throws {
        let fileURL = try makeTempFile(name: "guide.md")

        let action = LocalFileLinkResolver.resolve(fileURL)

        switch action {
        case .openMarkdownInNewWindow(let url):
            XCTAssertEqual(url.lastPathComponent, "guide.md")
        default:
            XCTFail("Expected markdown file to open in new window")
        }
    }

    func testResolveMarkdownExtensionCaseInsensitive() throws {
        let fileURL = try makeTempFile(name: "guide.MarkDown")

        let action = LocalFileLinkResolver.resolve(fileURL)

        switch action {
        case .openMarkdownInNewWindow:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected case-insensitive markdown extension handling")
        }
    }

    func testResolveNonMarkdownFileAsRevealParentDirectory() throws {
        let fileURL = try makeTempFile(name: "notes.txt")

        let action = LocalFileLinkResolver.resolve(fileURL)

        switch action {
        case .revealParentDirectory(let directoryURL):
            XCTAssertEqual(directoryURL.path, fileURL.deletingLastPathComponent().path)
        default:
            XCTFail("Expected non-markdown file to reveal parent directory")
        }
    }

    func testResolveMissingFileAsMissing() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")

        let action = LocalFileLinkResolver.resolve(fileURL)

        switch action {
        case .missingFile(let url):
            XCTAssertEqual(url.path, fileURL.standardizedFileURL.path)
        default:
            XCTFail("Expected missing file result")
        }
    }

    private func makeTempFile(name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent(name)
        try "x".write(to: fileURL, atomically: true, encoding: .utf8)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return fileURL
    }
}
