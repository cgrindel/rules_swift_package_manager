@testable import GreetingsFramework
import XCTest

class NamedGreetingTests: XCTestCase {
    func test_value() throws {
        let ng = NamedGreeting(
            MorningGreeting(),
            CustomNameProvider()
        )
        XCTAssertEqual(ng.value, "Good morning, Jim!")
    }
}

struct CustomNameProvider: NameProvider {
    var name = "Jim"
}
