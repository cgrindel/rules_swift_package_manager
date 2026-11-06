# Explicit modules example

This example consumes a local Swift package through rules_swift_package_manager. The package has
a Swift library importing Foundation, an Objective-C library with Foundation headers, and a text
resource accessed through the generated `Bundle.module` accessor.

On macOS with Xcode selected, run:

```sh
./do_test
```

The integration test builds and runs the same macOS application in three configurations:

1. Implicit modules, using the normal build configuration.
2. Explicit Clang modules with `--config=explicit_modules`.
3. Explicit Clang modules and explicit Swift module maps with `--config=explicit_swift_modules`.

Both explicit configurations retain rules_swift's default SDK dependencies. No manual SDK
dependencies or dependency-inference configuration are required. The executable checks the
greeting assembled by the Objective-C dependency and Swift resource accessor.

The example's `MODULE.bazel` excludes `MobileGestaltPrivate` from the macOS and iOS SDKs,
matching [rules_swift's own configuration](https://github.com/bazelbuild/rules_swift/blob/4.2.1/MODULE.bazel#L202-L253).
Xcode 27 ships its Swift interface without the underlying Objective-C module, so
precompiling it fails. SDK exclusions must be configured in the consuming root
module; rules_swift's own exclusions do not propagate to this example. Setting
`exclude_modules` replaces rules_swift's default exclusions, so the example restates
the `CoreAudio_Private` default for the iOS simulator.

`macos_application` assembles the transitive Apple resource bundles inside the application bundle.
A plain `swift_binary` does not assemble these bundles and cannot run this `Bundle.module` check
by itself. The application runs its assertion and exits without opening a window.

For setup details and limitations, see the [migration notes].

[migration notes]: /docs/rules_swift_4_migration.md
