// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "explicit_modules_example",
    dependencies: [
        .package(path: "third_party/ExplicitModulesFixture"),
    ]
)
