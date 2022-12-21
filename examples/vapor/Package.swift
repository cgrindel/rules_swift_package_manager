// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "vapor-example",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", exact: "4.56.0"),
        .package(url: "https://github.com/vapor/fluent.git", exact: "4.4.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", exact: "4.1.0"),
    ]
)
