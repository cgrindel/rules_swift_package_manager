// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift_protobuf_example",
    dependencies: [
        // These are the versions used by rules_swift
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.28.1"),
    ]
)
