// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "swift_package_registry_example",
    dependencies: [
        .package(id: "apple.swift-collections", exact: "1.1.3"),
        .package(id: "apple.swift-nio", exact: "2.76.1"),
    ]
)
