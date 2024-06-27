// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "smtp_example",
    dependencies: [
        .package(url: "https://github.com/sersoft-gmbh/swift-smtp", from: "2.10.0"),
    ]
)
