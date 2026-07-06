// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "CGreeter",
    products: [
        .library(name: "CGreeter", targets: ["CGreeter"]),
    ],
    targets: [
        .target(
            name: "CGreeter",
            path: "Sources/CGreeter",
            publicHeadersPath: "include"
        ),
    ]
)
