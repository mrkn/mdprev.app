import Foundation

enum AppOpenFileConsumerSelector {
    static func isPreferred(
        candidateWindowNumber: Int?,
        keyWindowNumber: Int?,
        mainWindowNumber: Int?,
        orderedWindowNumbers: [Int]
    ) -> Bool {
        guard let candidateWindowNumber else {
            return false
        }

        if let keyWindowNumber {
            return candidateWindowNumber == keyWindowNumber
        }

        if let mainWindowNumber {
            return candidateWindowNumber == mainWindowNumber
        }

        if let firstWindowNumber = orderedWindowNumbers.min() {
            return candidateWindowNumber == firstWindowNumber
        }

        return true
    }
}
