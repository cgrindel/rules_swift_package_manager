// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "resources_example",
    dependencies: [
        // .package(url: "https://github.com/apple/swift-log", from: "1.4.4"),
        .package(path: "third_party/package_with_resources"),
    ]
)
