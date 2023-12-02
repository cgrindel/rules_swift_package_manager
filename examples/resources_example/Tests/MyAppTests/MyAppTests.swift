import AppLovinSDKResources
import CoolUI
import SwiftUI
import XCTest

class MyAppTests: XCTestCase {
    func test_CoolStuf_title_doesNotFail() throws {
        let actual = CoolStuff.title()
        XCTAssertNotNil(actual)
    }

    func test_AppLovinSDKResources() throws {
        let url = ALResourceManager.resourceBundleURL
        XCTAssertNotNil(url)
    }
}
