// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "nimble_example",
    dependencies: [
        .package(
            url: "https://github.com/Quick/Quick",
            from: "5.0.1"
        ),
       .package(
            url: "https://github.com/Quick/Nimble",
            from: "10.0.0"
        )
    ],
    targets: [
        .testTarget(
            name: "CounterTests",
            dependencies: [
                "Quick",
                "Nimble"
            ],
            path: "./Sources/NimbleExample/NimbleExampleTests"
        )
    ]
)
