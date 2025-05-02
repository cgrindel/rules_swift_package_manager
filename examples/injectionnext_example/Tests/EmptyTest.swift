import InjectionNext
import XCTest

final class EmptyTest: XCTestCase {
    func test_anything() {
        _ = InjectionNext.self
        XCTAssertTrue(true)
    }
}
