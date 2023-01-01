@testable import MyDequeModule
import XCTest

class CreateTests: XCTestCase {
    func test_MyDeques_colors() throws {
        XCTAssertEqual(MyDeques.colors.count, 3)
    }

    static var allTests = [
      ("test_MyDeques_colors", test_MyDeques_colors),
    ]
}
