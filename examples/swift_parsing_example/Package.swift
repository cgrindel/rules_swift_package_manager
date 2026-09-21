// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift_parsing_example",
    platforms: [.macOS(.v15), .iOS(.v18)],
    dependencies: [
        // Under Swift 6.4, swift-parsing (iOS 13 / macOS 10.15) resolves
        // swift-case-paths 1.10.0 whose manifest declares iOS 15 / macOS 12.
        .package(url: "https://github.com/pointfreeco/swift-parsing", exact: "0.15.2"),
        // Toolchain-independent stand-in for the same shape: LocalLow
        // (macOS 10.15 / iOS 13) depends on LocalHigh (macOS 13 / iOS 16).
        .package(path: "LocalLow"),
    ]
)
