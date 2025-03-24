@testable import Models
import XCTest

final class ModelsTests: XCTestCase {
    func attributedString(with text: String) -> NSAttributedString {
        let nsString = NSString(string: text)
        var mutableAttributedString = NSMutableAttributedString(string: text)
        return mutableAttributedString
    }

    func test_models() {
        let attributedText = attributedString(with: "hello")
        let user = MockUser(senderId: "000001", displayName: "Nathan Tannar")
        let uniqueID = UUID().uuidString
        let date = Date()
        let msg = MockMessage(
            attributedText: attributedText,
            user: user,
            messageId: uniqueID,
            date: date
        )
    }
}
