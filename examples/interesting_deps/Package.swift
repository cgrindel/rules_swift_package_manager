// swift-tools-version: 5.7

import Foundation
import PackageDescription

// Use an environment variable to test `env` handling of the module extension + repo rules.
// Set the non-env case to a purposefully invalid value.
let dependencies: [Package.Dependency] = {
    let env = ProcessInfo.processInfo.environment
    if env["INTERESTING_DEPS_ENV"] == "1" && env["INTERESTING_DEPS_INHERIT_ENV"] == "1" {
        return [
            .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", from: "3.8.5"),
            .package(url: "https://github.com/GEOSwift/GEOSwift", from: "11.2.0"),
            .package(url: "https://github.com/OpenCombine/OpenCombine", from: "0.14.0"),
            .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.5.0"),
            .package(url: "https://github.com/apple/swift-log", from: "1.6.3"),
            .package(url: "https://github.com/erikdoe/ocmock", from: "3.9.4"),
            .package(url: "https://github.com/getyoti/yoti-doc-scan-ios.git", from: "7.0.0"),
            .package(url: "https://github.com/luispadron/swift-package-defines-example", from: "2.0.0"),
        ]
    } else {
        return [
            .package(url: "https://github.com/not-a-real-package/not-a-real-package", from: "1.0.0"),
        ]
    }
}()

let package = Package(
    name: "MySwiftPackage",
    dependencies: dependencies
)
