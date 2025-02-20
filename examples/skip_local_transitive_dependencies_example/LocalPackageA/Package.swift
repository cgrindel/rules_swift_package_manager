// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocalPackageA",
    products: [
        .library(name: "LocalPackageA", targets: ["LocalPackageA"]),
    ],
    dependencies: [
        .package(path: "../LocalPackageB"),
    ],
    targets: [
        .target(
            name: "LocalPackageA",
            dependencies: ["LocalPackageB"]
        ),
    ]
)
