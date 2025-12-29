// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "language_modes_example",
    dependencies: [
        .package(path: "third_party/swift_5_package"),
        .package(path: "third_party/swift_5_package_v6"),
        .package(path: "third_party/swift_6_package"),

        // At least one remote dependency is needed to generate Package.resolved
        .package(url: "https://github.com/apple/swift-log", from: "1.8.0"),
    ]
)
