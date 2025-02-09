// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MyLocalPackage",
    products: [
        .executable(name: "print-greeting", targets: ["PrintGreeting"]),
        .executable(name: "print-farewell", targets: ["PrintFarewell"]),
        .library(
            name: "GreetingsFramework",
            targets: ["GreetingsFramework"]
        ),
        .library(
            name: "FarewellFramework",
            targets: ["FarewellFramework"]
        ),
    ],
    targets: [
        // Puposefully, using the old-style pattern of a regular target being used by an executable
        // product.
        .executableTarget(
            name: "PrintGreeting",
            dependencies: ["GreetingsFramework"]
        ),
        .executableTarget(
            name: "PrintFarewell",
            dependencies: ["FarewellFramework"]
        ),
        .target(
            name: "GreetingsFramework",
            dependencies: []
        ),
        .target(
            name: "FarewellFramework",
            dependencies: []
        ),
        .testTarget(
            name: "GreetingsFrameworkTests",
            dependencies: ["GreetingsFramework"]
        ),
    ]
)
