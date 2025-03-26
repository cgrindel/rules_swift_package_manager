// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "grpc_example",
    dependencies: [
        // These are the versions used by rules_swift 1.18.0
        .package(url: "https://github.com/grpc/grpc-swift.git", exact: "1.24.2"),
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.20.2"),
    ]
)
