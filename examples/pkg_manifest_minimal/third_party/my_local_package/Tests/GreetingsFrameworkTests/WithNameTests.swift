@testable import GreetingsFramework
import XCTest

class WithNameTests: XCTestCase {
    func test_init() throws {
        let withName = WithName("George")
        XCTAssertEqual(withName.name, "George")
    }
}
