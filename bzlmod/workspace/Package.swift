// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MySwiftPackage",
    products: [
        .executable(name: "my-executable", targets: ["MyExecutable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.3"),
    ],
    targets: [
        .executableTarget(
            name: "MyExecutable",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                "MyLibrary",
                "System",
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
        .target(
            name: "System",
            dependencies: [],
            path: "Sources/System",
            exclude: [
                "BUILD.bazel",
                "README.md",
            ]
        ),
    ]
)
