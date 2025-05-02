// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "injectionnext_example",
    dependencies: [
        .package(url: "https://github.com/johnno1962/InjectionNext.git", from: "1.3.1"),
    ],
    targets: [
        .testTarget(
            name: "SomeTest",
            dependencies: [.product(name: "InjectionNext", package: "InjectionNext")],
            path: "Tests"
        )
    ]
)
