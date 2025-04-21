// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "tca_example",
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            .upToNextMajor(from: "1.19.1")
        ),
    ]
)
