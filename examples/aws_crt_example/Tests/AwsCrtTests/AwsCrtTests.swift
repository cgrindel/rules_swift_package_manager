import XCTest
import AwsCommonRuntimeKit

final class AwsCrtTests: XCTestCase {
    func testCrtTypes() throws {
        // Test that we can use types from AwsCommonRuntimeKit
        let logLevel = LogLevel.info
        XCTAssertEqual(logLevel, LogLevel.info)
    }
}
