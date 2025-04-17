// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "grpc_example",
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", exact: "2.1.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", exact: "1.1.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", exact: "1.0.1"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.1"),
    ]
)
