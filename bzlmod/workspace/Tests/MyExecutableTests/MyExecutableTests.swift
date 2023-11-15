@testable import MyExecutable
import XCTest

final class MyExecutableTests: XCTestCase {
    func testMyExecutable() throws {
        MyExecutable.main()
        XCTAssertEqual(MyExecutable.configuration.commandName, "my-executable")
    }

    static var allTests = [
      ("testMyExecutable", testMyExecutable),
    ]
}
