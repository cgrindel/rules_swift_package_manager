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
        .library(name: "ExcludedFiles", targets: ["ExcludedFiles"]),
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
        // SwiftPM does not compile excluded files, but excluded_files.c still
        // #includes them.
        .target(
            name: "ExcludedFiles",
            exclude: ["excluded_prefix.h", "excluded_table.c"]
        ),
        .testTarget(
            name: "GreetingsFrameworkTests",
            dependencies: ["GreetingsFramework"]
        ),
    ]
)
