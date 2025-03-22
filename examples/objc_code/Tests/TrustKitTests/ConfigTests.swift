import TrustKit
import XCTest

class ConfigTests: XCTestCase {
    func test_config() throws {
        let trustKitConfig =
            [
                kTSKSwizzleNetworkDelegates: false,
                kTSKPinnedDomains:
                    [
                        "yahoo.com": [
                            kTSKExpirationDate: "2022-02-08",
                            kTSKPublicKeyHashes:
                                [
                                    "JbQbUG5JMJUoI6brnx0x3vZF6jilxsapbXGVfjhN8Fg=",
                                    "WoiWRyIOVNa9ihaBciRSC7XHjliYS9VwUGOIud4PB18=",
                                ],
                        ],
                    ],
            ] as [String: Any]

        TrustKit.setLoggerBlock {
            print($0)
        }

        _ = TrustKit(configuration: trustKitConfig)
    }
}
