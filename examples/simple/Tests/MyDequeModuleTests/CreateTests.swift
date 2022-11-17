@testable import MyDequeModule
import XCTest

class CreateTests: XCTestCase {
    func test_MyDeques_colors() throws {
        XCTAssertEqual(MyDeques.colors.count, 3)
    }
}
