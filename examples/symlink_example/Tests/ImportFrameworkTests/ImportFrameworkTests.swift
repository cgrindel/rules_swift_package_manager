import XCTest
@testable import ImportFramework

final class ImportFrameworkTests: XCTestCase {
    func testVersionNumber() throws {
        XCTAssertEqual(getFrameworkVersion(), 1.0)
    }
}
