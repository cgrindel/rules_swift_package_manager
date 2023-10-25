// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "resources_example",
    dependencies: [
        .package(path: "third_party/package_with_resources"),
        .package(path: "third_party/another_package_with_resources"),
    ]
)
