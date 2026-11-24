// swift-tools-version: 5.9

import PackageDescription

// `swift-system` is a dependency only on Linux, so the `apple` slice does not
// pin it at all and its repository gets a failing branch for that slice.
var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
]
var targetDependencies: [Target.Dependency] = [
    .product(name: "Logging", package: "swift-log"),
]
#if os(Linux)
packageDependencies.append(
    .package(url: "https://github.com/apple/swift-system", from: "1.4.0")
)
targetDependencies.append(
    .product(name: "SystemPackage", package: "swift-system")
)
#endif

let package = Package(
    name: "multi_slice",
    dependencies: packageDependencies,
    targets: [
        .executableTarget(
            name: "MultiSlice",
            dependencies: targetDependencies,
            path: "Sources/MultiSlice",
            exclude: ["BUILD.bazel"]
        ),
    ]
)
