// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "symlink_example",
    dependencies: [
        .package(path: "third_party/empty_framework"),
    ]
)
