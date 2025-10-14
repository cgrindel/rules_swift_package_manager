// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "ios_sim",
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", exact: "2.86.2"),
        .package(url: "https://github.com/apple/swift-markdown.git", exact: "0.7.2"),
    ]
)
