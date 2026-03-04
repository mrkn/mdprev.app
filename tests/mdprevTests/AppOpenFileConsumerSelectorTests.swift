import XCTest
@testable import mdprev

final class AppOpenFileConsumerSelectorTests: XCTestCase {
    func testSelectsKeyWindowWhenAvailable() {
        let preferred = AppOpenFileConsumerSelector.isPreferred(
            candidateWindowNumber: 12,
            keyWindowNumber: 12,
            mainWindowNumber: 7,
            orderedWindowNumbers: [7, 12, 18]
        )
        let notPreferred = AppOpenFileConsumerSelector.isPreferred(
            candidateWindowNumber: 7,
            keyWindowNumber: 12,
            mainWindowNumber: 7,
            orderedWindowNumbers: [7, 12, 18]
        )

        XCTAssertTrue(preferred)
        XCTAssertFalse(notPreferred)
    }

    func testFallsBackToMainWindowWhenKeyWindowIsUnavailable() {
        let preferred = AppOpenFileConsumerSelector.isPreferred(
            candidateWindowNumber: 7,
            keyWindowNumber: nil,
            mainWindowNumber: 7,
            orderedWindowNumbers: [7, 12, 18]
        )
        let notPreferred = AppOpenFileConsumerSelector.isPreferred(
            candidateWindowNumber: 12,
            keyWindowNumber: nil,
            mainWindowNumber: 7,
            orderedWindowNumbers: [7, 12, 18]
        )

        XCTAssertTrue(preferred)
        XCTAssertFalse(notPreferred)
    }

    func testFallsBackToLowestWindowNumberWhenKeyAndMainAreUnavailable() {
        let preferred = AppOpenFileConsumerSelector.isPreferred(
            candidateWindowNumber: 5,
            keyWindowNumber: nil,
            mainWindowNumber: nil,
            orderedWindowNumbers: [11, 5, 9]
        )
        let notPreferred = AppOpenFileConsumerSelector.isPreferred(
            candidateWindowNumber: 9,
            keyWindowNumber: nil,
            mainWindowNumber: nil,
            orderedWindowNumbers: [11, 5, 9]
        )

        XCTAssertTrue(preferred)
        XCTAssertFalse(notPreferred)
    }

    func testCandidateIsNotPreferredWhenWindowNumberIsUnavailable() {
        let preferred = AppOpenFileConsumerSelector.isPreferred(
            candidateWindowNumber: nil,
            keyWindowNumber: 12,
            mainWindowNumber: 7,
            orderedWindowNumbers: [7, 12]
        )

        XCTAssertFalse(preferred)
    }

    func testSingleCandidateIsPreferredWhenNoSystemWindowsAreKnown() {
        let preferred = AppOpenFileConsumerSelector.isPreferred(
            candidateWindowNumber: 42,
            keyWindowNumber: nil,
            mainWindowNumber: nil,
            orderedWindowNumbers: []
        )

        XCTAssertTrue(preferred)
    }
}
