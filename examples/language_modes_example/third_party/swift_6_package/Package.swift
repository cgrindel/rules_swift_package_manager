// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift_6_package",
    products: [
        .library(name: "Tools6", targets: ["Tools6"]),
        .library(name: "Tools6_Mode5", targets: ["Tools6_Mode5"]),
    ],
    targets: [
        // Target that inherits Swift 6 language mode from the package tools version
        .target(name: "Tools6"),
        // Target that sets an explicit Swift 5 language mode
        .target(
            name: "Tools6_Mode5",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
