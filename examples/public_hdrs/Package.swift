// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MySwiftPackage",
    dependencies: [
        .package(url: "https://github.com/datatheorem/TrustKit.git", from: "2.0.0"),
    ]
)
