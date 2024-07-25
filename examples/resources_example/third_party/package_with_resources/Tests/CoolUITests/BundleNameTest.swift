import Foundation
import XCTest

@testable import CoolUI

class BundleNameTest: XCTestCase {
    func testBundleName() {
        let bundle = Bundle.bundle(named: "package-with-resources_CoolUI")
        XCTAssertNotNil(bundle)
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
