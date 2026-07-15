// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "module_aliases_example",
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.14.0"),
        .package(path: "third_party/swift-draw"),
        .package(path: "third_party/swift-game"),
    ],
    targets: [
        // This target is never built by Bazel. It exists to declare SE-0339
        // module aliases, which rules_swift_package_manager reads from this
        // manifest.
        //
        // - swift-log's `Logging` module is renamed to `SwiftLog` so that it
        //   cannot collide with this example's first-party `Logging` module
        //   (see the root BUILD.bazel).
        // - swift-game and swift-draw both provide a module named `Utils`.
        //   Only swift-game's module is renamed (to `GameUtils`); the alias
        //   is scoped to swift-game, so swift-draw's `Utils` keeps its
        //   original name.
        .target(
            name: "ModuleAliases",
            dependencies: [
                .product(name: "Logging", package: "swift-log", moduleAliases: ["Logging": "SwiftLog"]),
                .product(name: "Utils", package: "swift-game", moduleAliases: ["Utils": "GameUtils"]),
                .product(name: "Utils", package: "swift-draw"),
            ]
        ),
    ]
)
