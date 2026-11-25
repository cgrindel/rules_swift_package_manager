// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "package-with-resources-swift-6",
    defaultLocalization: "en",
    platforms: [.iOS(.v13), .macOS(.v13)],
    products: [
        .library(name: "CoolUI", targets: ["CoolUI"]),
    ],
    targets: [
        .target(
            name: "CoolUI",
            resources: [.process("Resources")],
            swiftSettings: [
                // Future Swift features
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),

                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "CoolUITests",
            dependencies: ["CoolUI"],
            swiftSettings: [
                // Future Swift features
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),

                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
