# Explicit modules example

This example consumes a local Swift package through rules_swift_package_manager. The package has
a Swift library importing Foundation, an Objective-C library with Foundation headers, and a text
resource accessed through the generated `Bundle.module` accessor.

On macOS with Xcode selected, run:

```sh
./do_test
```

The integration test builds and runs the same binary in three configurations:

1. Implicit modules, using the normal build configuration.
2. Explicit Clang modules with `--config=explicit_modules`.
3. Explicit Clang modules and explicit Swift module maps with `--config=explicit_swift_modules`.

Both explicit configurations retain rules_swift's default SDK dependencies. No manual SDK
dependencies or dependency-inference configuration are required. The executable checks the
greeting assembled by the Objective-C dependency and Swift resource accessor.

For setup details and limitations, see the [migration notes].

[migration notes]: /docs/rules_swift_4_migration.md
