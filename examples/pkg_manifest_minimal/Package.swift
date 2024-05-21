// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MySwiftPackage",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.4"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.53.10"),
        .package(path: "third_party/my_local_package"),
        .package(path: "third_party/NotThatAmazingModule"),
    ]
)
