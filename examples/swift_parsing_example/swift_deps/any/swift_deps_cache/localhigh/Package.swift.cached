// swift-tools-version: 5.9

import PackageDescription

// Declares a higher minimum OS than `LocalLow`, which depends on it. Stands in
// for swift-case-paths' Swift 6.4 manifest so the floor propagation is
// exercised regardless of the toolchain used to build this example.
let package = Package(
    name: "LocalHigh",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "LocalHigh", targets: ["LocalHigh"]),
    ],
    targets: [
        .target(name: "LocalHigh"),
    ]
)
