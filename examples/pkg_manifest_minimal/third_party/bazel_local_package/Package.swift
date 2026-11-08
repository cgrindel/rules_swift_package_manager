// swift-tools-version: 5.9

import PackageDescription

// A local package that is also a Bazel package, with BUILD files at its root
// and in its target's directory.
let package = Package(
    name: "BazelLocalPackage",
    products: [
        .library(name: "BazelLocalModule", targets: ["BazelLocalModule"]),
    ],
    targets: [
        .target(name: "BazelLocalModule"),
    ]
)
