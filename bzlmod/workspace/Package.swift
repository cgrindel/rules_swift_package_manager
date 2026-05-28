// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MySwiftPackage",
    products: [
        .executable(name: "my-executable", targets: ["MyExecutable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.1"),
        // swift-log 1.9.0+ declares swift-tools-version >= 6.1, which the
        // BCR macOS Buildkite runner's installed Swift (6.0.x) cannot parse.
        // Cap below 1.9.0 so SPM resolves to 1.8.0, whose manifest declares
        // swift-tools-version 6.0 and is readable on the runner. Drop the
        // upper bound once BCR's runner ships Swift >= 6.2.
        .package(url: "https://github.com/apple/swift-log", "1.5.4" ..< "1.12.1"),
    ],
    targets: [
        .executableTarget(
            name: "MyExecutable",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                "MyLibrary",
            ],
            path: "Sources/MyExecutable",
            exclude: ["BUILD.bazel"]
        ),
        .target(
            name: "MyLibrary",
            dependencies: [],
            path: "Sources/MyLibrary",
            exclude: ["BUILD.bazel"]
        ),
        .testTarget(
            name: "MyLibraryTests",
            dependencies: ["MyLibrary"],
            path: "Tests/MyLibraryTests",
            exclude: ["BUILD.bazel"]
        ),
    ]
)
