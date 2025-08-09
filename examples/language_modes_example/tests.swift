import Tools5
import Tools5_Mode6
import Tools6
import Tools6_Mode5

import XCTest

final class LanguageModeTests: XCTestCase {
    func test_Tools5() {
        XCTAssertEqual(Tools5.getLanguageMode(), 5)
    }

    func test_Tools5_Mode6() {
        XCTAssertEqual(Tools5_Mode6.getLanguageMode(), 6)
    }

    func test_Tools6() {
        XCTAssertEqual(Tools6.getLanguageMode(), 6)
    }

    func test_Tools6_Mode5() {
        XCTAssertEqual(Tools6_Mode5.getLanguageMode(), 5)
    }
}