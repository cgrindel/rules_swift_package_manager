// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "ios_sim",
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", exact: "2.85.0"),
        .package(url: "https://github.com/apple/swift-markdown.git", exact: "0.6.0"),
    ]
)
