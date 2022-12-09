// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MySwiftPackage",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "sayhello", targets: ["MyExecutable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "MyExecutable",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "MyLibrary",
            ]
        ),
        .target(
            name: "MyLibrary"),
        .testTarget(
            name: "MyLibraryTests",
            dependencies: ["MyLibrary"]
        ),
    ]
)
