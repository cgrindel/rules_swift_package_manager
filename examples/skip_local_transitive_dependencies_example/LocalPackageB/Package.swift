// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocalPackageB",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(name: "LocalPackageB", targets: ["LocalPackageB"]),
    ],
    dependencies: [
        .package(url: "https://github.com/OpenCombine/OpenCombine", from: "0.14.0"),
    ],
    targets: [
        .target(
            name: "LocalPackageB",
            dependencies: [
                .product(name: "OpenCombine", package: "OpenCombine"),
            ]
        ),
    ]
)
