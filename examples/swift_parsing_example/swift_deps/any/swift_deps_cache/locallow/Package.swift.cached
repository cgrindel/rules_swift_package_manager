// swift-tools-version: 5.9

import PackageDescription

// Declares a lower minimum OS than its dependency `LocalHigh`, like
// swift-parsing importing swift-case-paths. SwiftPM raises `LocalLow`'s
// deployment target to `LocalHigh`'s; rules_swift_package_manager must too.
let package = Package(
    name: "LocalLow",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(name: "LocalLow", targets: ["LocalLow"]),
    ],
    dependencies: [
        .package(path: "../LocalHigh"),
    ],
    targets: [
        .target(name: "LocalLow", dependencies: ["LocalHigh"]),
    ]
)
