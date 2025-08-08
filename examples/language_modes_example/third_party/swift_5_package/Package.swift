// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "swift_5_package",
    products: [
        .library(name: "Tools5", targets: ["Tools5"]),
    ],
    targets: [
        // Target that inherits Swift 5 language mode from the package tools version
        .target(name: "Tools5"),
    ]
)
