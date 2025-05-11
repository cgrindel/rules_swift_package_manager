// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "shake_ios_example",
    dependencies: [
        .package(url: "https://github.com/shakebugs/shake-ios", from: "17.1.1"),
    ]
)
