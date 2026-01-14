// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "multiple_rules_spm_example",
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
        .package(url: "https://github.com/vapor/vapor.git", .upToNextMajor(from: "4.116.0")),
    ]
)
