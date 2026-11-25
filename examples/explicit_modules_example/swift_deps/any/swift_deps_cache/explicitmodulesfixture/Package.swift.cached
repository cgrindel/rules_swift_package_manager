// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "ExplicitModulesFixture",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Greeter", targets: ["Greeter"]),
    ],
    targets: [
        .target(
            name: "Greeter",
            dependencies: ["ObjCGreeter"],
            resources: [.process("Resources")]
        ),
        .target(name: "ObjCGreeter"),
    ]
)
