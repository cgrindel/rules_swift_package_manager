// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "nimble_example",
    dependencies: [
        .package(
            url: "https://github.com/Quick/Quick",
            from: "7.5.0"
        ),
        .package(
            url: "https://github.com/Quick/Nimble",
            from: "13.3.0"
        ),
    ],
    targets: [
        .testTarget(
            name: "CounterTests",
            dependencies: [
                "Quick",
                "Nimble",
            ],
            path: "./Sources/NimbleExample/NimbleExampleTests"
        ),
    ]
)
