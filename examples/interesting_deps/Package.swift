// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MySwiftPackage",
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.5.2"),
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.3.1"),
        .package(url: "https://github.com/scaraux/Swift-Porter-Stemmer-2.git", from: "0.1.1"),
    ]
)
