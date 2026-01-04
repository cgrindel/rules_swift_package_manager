// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "grdb_example",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", exact: "7.4.1"),
    ]
)
