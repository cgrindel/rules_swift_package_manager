// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "messagekit_example",
    dependencies: [
        .package(url: "https://github.com/MessageKit/MessageKit", from: "3.7.0"),
        .package(url: "https://github.com/onevcat/Kingfisher", from: "5.15.8"),
    ]
)
