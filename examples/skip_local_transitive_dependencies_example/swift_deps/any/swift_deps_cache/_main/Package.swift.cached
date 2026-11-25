// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "skip_local_transitive_dependencies_example",
    dependencies: [
        // The `skip_local_transitive_dependencies_example` binary only depends directly on
        // LocalPackageA. LocalPackageB is listed too, as v1 required when
        // `resolve_transitive_local_dependencies` was `False`.
        .package(path: "LocalPackageA"),
        .package(path: "LocalPackageB"),
    ]
)
