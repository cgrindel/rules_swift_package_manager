import AppLovinSDKResources
import CoolUI
import CoreData
@testable import IterableSDK
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
        // Log Iterable messages to an array
        class LogDelegate: IterableLogDelegate {
            var messages: [String] = []
            
            func log(level: LogLevel, message: String) {
                messages.append(message)
            }
        }
        
        let logDelegate = LogDelegate()
        IterableLogUtil.sharedInstance = IterableLogUtil(
            dateProvider: SystemDateProvider(),
            logDelegate: logDelegate
        )

        // Create the persistence container from the bundled CoreData model
        let container: PersistentContainer? = PersistentContainer.initialize()
        XCTAssertNotNil(container)
        
        // Assert that the persistence container was successfully created
        let lastMessage = try XCTUnwrap(logDelegate.messages.last)
        XCTAssert(
            lastMessage.contains("Successfully loaded persistent store at:"),
            "Expected success log message. Found: \(logDelegate.messages.last ?? "nil")"
        )
        
        IterableLogUtil.sharedInstance = nil
    }
}
