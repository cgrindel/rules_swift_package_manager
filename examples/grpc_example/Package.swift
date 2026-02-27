// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "grpc_example",
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift-2.git", exact: "2.2.1"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", exact: "2.2.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", exact: "2.4.3"),
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.35.0"),
    ]
)
