// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "skip_local_transitive_dependencies_example",
    dependencies: [
        // The `skip_local_transitive_dependencies_example` binary only depends directly on
        // LocalPackageA, but LocalPackageB must also be added as a direct dependency because
        // `resolve_transitive_local_dependencies` is set to `False` in the MODULE.bazel file.
        .package(path: "LocalPackageA"),
        .package(path: "LocalPackageB"),
    ]
)
