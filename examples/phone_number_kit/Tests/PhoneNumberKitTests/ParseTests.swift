@testable import PhoneNumberKit
import XCTest

class ParseTests: XCTestCase {
    let phoneNumberUtility = PhoneNumberUtility()

    func test_parse() throws {
        let phoneNumber = try phoneNumberUtility.parse("+33 6 89 017383")
        XCTAssertNotNil(phoneNumber)
    }
}
