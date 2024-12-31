// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "grpc_example",
    dependencies: [
        // These are the versions used by rules_swift
        .package(url: "https://github.com/grpc/grpc-swift-extras", exact: "1.0.0-beta.2"),
        .package(url: "https://github.com/grpc/grpc-swift.git", exact: "2.0.0-beta.2"), // Required by grpc-swift-extras @ 1.0.0-beta.2
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", exact: "1.0.0-beta.2"), // Required by grpc-swift @ 2.0.0-beta.2
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", exact: "1.0.0-beta.2"), // Required by grpc-swift @ 2.0.0-beta.2
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.28.1"), // Required by grpc-swift @ 2.0.0-beta.2
    ]
)
