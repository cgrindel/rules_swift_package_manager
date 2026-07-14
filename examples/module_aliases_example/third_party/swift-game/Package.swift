// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "swift-game",
    products: [
        .library(name: "Utils", targets: ["Utils"]),
    ],
    dependencies: [
        // swift-game imports swift-log's `Logging` module. The root manifest
        // renames that module to `SwiftLog`, so swift-game — a direct
        // dependent of swift-log — must be compiled with
        // `-module-alias Logging=SwiftLog` for its `import Logging` to
        // resolve. This exercises propagation of a dependency's module alias
        // to a dependent package (not just to the package that declares it).
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "Utils",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
    ]
)
