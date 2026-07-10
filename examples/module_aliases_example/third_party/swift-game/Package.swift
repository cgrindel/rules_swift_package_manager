// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "swift-game",
    products: [
        .library(name: "Utils", targets: ["Utils"]),
    ],
    targets: [
        .target(name: "Utils"),
    ]
)
