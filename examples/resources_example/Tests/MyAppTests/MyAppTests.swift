import AppLovinSDKResources
import CoolUI
import CoreData
@testable import IterableSDK
import SwiftUI
import XCTest

class MyAppTests: XCTestCase {
    func test_CoolStuff_title_doesNotFail() throws {
        let actual = CoolStuff.title()
        XCTAssertNotNil(actual)
    }

    
    func test_CoolStuff_bundleName() {
        let bundle = Bundle.bundle(named: "package-with-resources_CoolUI")
        XCTAssertNotNil(bundle)
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

private class BundleFinder {}

extension Foundation.Bundle {
    static func bundle(named bundleName: String) -> Bundle? {
        let candidates = [
            // Bundle should be present here when the package is linked into an App.
            Bundle.main.resourceURL,
            
            // Bundle should be present here when the package is linked into a framework.
            Bundle(for: BundleFinder.self).resourceURL,
            
            // For command-line tools.
            Bundle.main.bundleURL,
            
            // Bundle should be present here when running previews from a different package (this is the path to "…/Debug-iphonesimulator/").
            Bundle(for: BundleFinder.self).resourceURL?.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent(),
            Bundle(for: BundleFinder.self).resourceURL?.deletingLastPathComponent().deletingLastPathComponent(),
        ]
        
        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }

        return nil
    }
}
