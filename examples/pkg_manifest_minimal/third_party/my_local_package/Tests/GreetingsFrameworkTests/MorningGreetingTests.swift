@testable import GreetingsFramework
import XCTest

final class MorningGreetingTests: XCTestCase {
    func testExample() throws {
        XCTAssertEqual(MorningGreeting().greeting, "Good morning")
    }
}
