@testable import StringUtils
import XCTest

class StaticStringTests: XCTestCase {
    func testSomething() {
        let staticString: StaticString = "foo"
        assertThat(staticString.toString()).isEqualTo("foo")
    }

    static var allTests = [
        ("testSomething", testSomething),
    ]
}
