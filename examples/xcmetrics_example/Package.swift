// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "xcmetrics_example",
    dependencies: [
        .package(url: "https://github.com/spotify/XCMetrics", from: "v0.0.13"),
    ]
)
