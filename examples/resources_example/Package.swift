// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "resources_example",
    dependencies: [
        .package(path: "third_party/package_with_resources"),
        .package(path: "third_party/another_package_with_resources"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0"),
        .package(
            url: "https://github.com/ciaranrobrien/SwiftUIFlow.git",
            revision: "b300d3c0110116f3520066dfb8dcf3006cf593c3"
        ),
    ]
)
