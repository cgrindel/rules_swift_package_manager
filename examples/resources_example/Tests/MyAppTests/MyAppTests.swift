import AppLovinSDKResources
import CoolUI
import IterableSDK
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
    
    func test_IterableDataModel() throws {
        let dataModelLoaded = expectation("Iterable CoreData model loaded")
        
        let container = NSPersistentContainer(name: "IterableDataModel")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "Loading persistence stores generated an error: \(error!)")
            dataModelLoaded.fulfill()
        }
    }
}
