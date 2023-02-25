@testable import PhoneNumberKit
import XCTest

class ParseTests: XCTestCase {
    let phoneNumberKit = PhoneNumberKit()

    func test_parse() throws {
        let phoneNumber = try phoneNumberKit.parse("+33 6 89 017383")
        XCTAssertNotNil(phoneNumber)
    }
}
