// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "grpc_example",
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", exact: "2.1.2"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", exact: "1.2.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", exact: "1.0.3"),
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.29.0"),
    ]
)
