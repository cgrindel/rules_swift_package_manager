# Explicit modules example

This example consumes a local Swift package through rules_swift_package_manager. The package has
a Swift library importing Foundation, an Objective-C library with Foundation headers, and a text
resource accessed through the generated `Bundle.module` accessor.

On macOS with Xcode selected, run:

```sh
./do_test
```

The integration test builds and runs the same macOS application in four configurations:

1. Implicit modules, using the normal build configuration.
2. Explicit Clang modules with `--config=explicit_modules`.
3. Explicit Clang modules and explicit Swift module maps with `--config=explicit_swift_modules`.
4. Explicit Clang modules with default SDK dependencies disabled, using `--config=inferred_modules`.

The first two explicit configurations retain rules_swift's default SDK dependencies. The
`inferred_modules` configuration exercises `configure_explicit_modules(system_sdk_deps = True)`
from `MODULE.bazel`, including Foundation imports in Swift and Objective-C and the generated
resource accessor. No manual SDK dependencies are required. The executable checks the
greeting assembled by the Objective-C dependency and Swift resource accessor.
The runner also builds an iOS simulator app with inferred SDK dependencies. The
fixture's iOS-only UIKit import verifies the iOS SDK select.

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

Source inference requires the SDK inventory provider from #2619. During the
independent rollout, `do_test` reports when that provider is absent and runs the
implicit/default-explicit configurations. Once the provider is present, it also
runs inferred modules and builds the iOS simulator app; inference failures are
not skipped. The consumer's unit tests use inventory fixtures in either case.
