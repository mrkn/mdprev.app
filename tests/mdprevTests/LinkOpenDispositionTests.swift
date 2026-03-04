import AppKit
import XCTest
@testable import mdprev

final class LinkOpenDispositionTests: XCTestCase {
    func testDefaultClickOpensCurrentTab() {
        let disposition = LinkOpenDisposition.from(modifierFlags: [])

        XCTAssertEqual(disposition, .currentTab)
    }

    func testCommandClickOpensNewTab() {
        let disposition = LinkOpenDisposition.from(modifierFlags: [.command])

        XCTAssertEqual(disposition, .newTab)
    }

    func testShiftClickOpensNewWindow() {
        let disposition = LinkOpenDisposition.from(modifierFlags: [.shift])

        XCTAssertEqual(disposition, .newWindow)
    }

    func testShiftTakesPriorityOverCommand() {
        let disposition = LinkOpenDisposition.from(modifierFlags: [.command, .shift])

        XCTAssertEqual(disposition, .newWindow)
    }
}
