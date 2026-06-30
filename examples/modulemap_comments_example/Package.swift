// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "modulemap_comments_example",
    dependencies: [
        .package(path: "third_party/CGreeter"),
    ]
)
