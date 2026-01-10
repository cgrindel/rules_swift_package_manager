// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AwsCrtExample",
    dependencies: [
        .package(url: "https://github.com/awslabs/aws-crt-swift.git", from: "0.56.0"),
    ]
)
