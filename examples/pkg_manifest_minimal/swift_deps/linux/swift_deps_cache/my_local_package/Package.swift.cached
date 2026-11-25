// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MyLocalPackage",
    products: [
        .executable(name: "print-greeting", targets: ["PrintGreeting"]),
        .library(
            name: "GreetingsFramework",
            targets: ["GreetingsFramework"]
        ),
    ],
    targets: [
        // Puposefully, using the old-style pattern of a regular target being used by an executable
        // product.
        .target(
            name: "PrintGreeting",
            dependencies: ["GreetingsFramework"]
        ),
        .target(
            name: "GreetingsFramework",
            dependencies: []
        ),
        .testTarget(
            name: "GreetingsFrameworkTests",
            dependencies: ["GreetingsFramework"]
        ),
    ]
)
