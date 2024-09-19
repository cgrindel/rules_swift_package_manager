// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "vapor_example",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", exact: "4.105.2"),
        .package(url: "https://github.com/vapor/fluent.git", exact: "4.11.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", exact: "4.7.4"),
    ]
)
