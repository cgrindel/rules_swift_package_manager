// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "sqlite_data_example",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/sqlite-data", exact: "1.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
    ]
)
