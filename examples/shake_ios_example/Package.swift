// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "shake_ios_example",
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.5.3"),
        .package(url: "https://github.com/shakebugs/shake-ios", from: "16.2.2"),
    ]
)
