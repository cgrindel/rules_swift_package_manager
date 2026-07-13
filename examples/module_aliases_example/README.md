# Module Aliases Example

This example demonstrates support for [SE-0339 module
aliases](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0339-module-aliasing-for-disambiguation.md)
declared in the root package manifest.

The example demonstrates two collisions:

1. A first-party Bazel module named `Logging` collides with the `Logging`
   module from [apple/swift-log](https://github.com/apple/swift-log). Two
   modules with the same name cannot coexist in one build under rules_swift's
   `swift.use_explicit_swift_module_map` feature (the explicit module map has
   one entry per module name, so one module silently shadows the other).
2. Two local packages, `third_party/swift-game` and `third_party/swift-draw`,
   both provide a module named `Utils` — the scenario from the SE-0339
   proposal.

`Package.swift` resolves both by renaming one side of each collision:

```swift
.product(name: "Logging", package: "swift-log", moduleAliases: ["Logging": "SwiftLog"]),
.product(name: "Utils", package: "swift-game", moduleAliases: ["Utils": "GameUtils"]),
.product(name: "Utils", package: "swift-draw"),
```

rules_swift_package_manager reads the aliases from the manifest and:

- compiles the matching Swift target in the providing package with the
  replacement module name (`SwiftLog`, `GameUtils`), and
- compiles the providing package and its direct dependents with
  `-module-alias` flags so package sources can keep writing the original
  `import`.

The aliases are scoped to the providing package: swift-draw's `Utils` module
keeps its original name even though swift-game's same-named module is renamed.

The alias also propagates to direct dependents. swift-game depends on swift-log
and its source writes `import Logging`, so swift-game is compiled with
`-module-alias Logging=SwiftLog` even though swift-game does not declare the
alias itself — otherwise its `import Logging` would fail to resolve now that
swift-log's module is named `SwiftLog`.

Bazel targets outside the package graph import the replacement name (see
`main.swift`, which imports the first-party `Logging`, `SwiftLog`,
`GameUtils`, and swift-draw's original `Utils`). Product labels are unchanged
by the alias — only modules are renamed — so the binary still depends on
`@swiftpkg_swift_log//:Logging`, `@swiftpkg_swift_game//:Utils`, and
`@swiftpkg_swift_draw//:Utils`.

Note: per SE-0339, only pure-Swift source modules can be aliased.
