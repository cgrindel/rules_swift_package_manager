// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "TargetCoptsFixture",
    products: [
        .library(name: "Selected", targets: ["Selected"]),
        .library(name: "Sibling", targets: ["Sibling"]),
    ],
    targets: [
        .target(name: "Selected"),
        .target(name: "Sibling"),
    ]
)
