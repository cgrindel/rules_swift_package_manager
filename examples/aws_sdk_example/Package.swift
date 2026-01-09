// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwsSdkExample",
    dependencies: [
        .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "1.6.31"),
    ]
)
