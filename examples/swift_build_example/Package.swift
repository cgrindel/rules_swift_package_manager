// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift_build_example",
    dependencies: [
        .package(url: "https://github.com/maxwellE/swift-build", branch: "maxwelle/bazel-poc"),
    ]
)
