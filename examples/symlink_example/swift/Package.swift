// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "symlink_example",
    products: [
        .library(name: "symlink_example", targets: ["EmptyFramework"])
    ],
    targets: [
        .binaryTarget(name: "EmptyFramework", path: "../EmptyFramework.xcframework")
    ]
)
