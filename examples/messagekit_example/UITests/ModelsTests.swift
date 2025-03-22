@testable import Models
import XCTest

final class ModelsTests: XCTestCase {
    func attributedString(with text: String) -> NSAttributedString {
        let nsString = NSString(string: text)
        var mutableAttributedString = NSMutableAttributedString(string: text)
        return mutableAttributedString
    }

    func test_models() {
        let attributedText = attributedString(with: randomSentence)
        let msg = MockMessage(attributedText: attributedText, user: user, messageId: uniqueID, date: date)
    }
}
