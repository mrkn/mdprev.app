import AppKit
import XCTest
@testable import mdprev

final class RecentFileOpenActionTests: XCTestCase {
    func testOptionClickWithFocusedModelOpensInNewWindow() {
        let action = RecentFileOpenAction.from(
            modifierFlags: [.option],
            hasFocusedModel: true
        )

        XCTAssertEqual(action, .openInNewWindow)
    }

    func testOptionClickWithoutFocusedModelOpensInNewWindow() {
        let action = RecentFileOpenAction.from(
            modifierFlags: [.option],
            hasFocusedModel: false
        )

        XCTAssertEqual(action, .openInNewWindow)
    }

    func testPlainClickWithFocusedModelOpensInFocusedWindow() {
        let action = RecentFileOpenAction.from(
            modifierFlags: [],
            hasFocusedModel: true
        )

        XCTAssertEqual(action, .openInFocusedWindow)
    }

    func testPlainClickWithoutFocusedModelOpensInNewWindow() {
        let action = RecentFileOpenAction.from(
            modifierFlags: [],
            hasFocusedModel: false
        )

        XCTAssertEqual(action, .openInNewWindow)
    }

    func testOptionTakesPriorityOverOtherModifiers() {
        let action = RecentFileOpenAction.from(
            modifierFlags: [.option, .command, .shift],
            hasFocusedModel: true
        )

        XCTAssertEqual(action, .openInNewWindow)
    }
}
