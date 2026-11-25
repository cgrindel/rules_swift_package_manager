// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "another-package-with-resources",
    defaultLocalization: "en",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "MoreCoolUI", targets: ["MoreCoolUI"]),
    ],
    targets: [
        .target(
            name: "MoreCoolUI",
            path: "",
            resources: [.process("Resources")]
        ),
    ]
)
