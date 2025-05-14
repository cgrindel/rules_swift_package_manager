// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MySwiftPackage",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.3"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.56.1"),
        .package(path: "third_party/my_local_package"),
        .package(path: "third_party/NotThatAmazingModule"),
    ]
)
