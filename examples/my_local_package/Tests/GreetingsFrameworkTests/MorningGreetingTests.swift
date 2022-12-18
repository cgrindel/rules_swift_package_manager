@testable import GreetingsFramework
import XCTest

final class MorningGreetingTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(MorningGreeting().text, "Good morning")
    }
}
