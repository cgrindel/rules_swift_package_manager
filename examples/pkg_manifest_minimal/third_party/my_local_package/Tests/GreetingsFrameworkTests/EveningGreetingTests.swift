@testable import GreetingsFramework
import XCTest

final class EveningGreetingTests: XCTestCase {
    func testExample() throws {
        XCTAssertEqual(EveningGreeting().greeting, "Good evening")
    }
}
