# Migrating to rules_swift 4.x

rules_swift_package_manager now requires rules_swift 4.2.1 or later. Consumers that already select
4.2.1 through their own `bazel_dep` do not need to change that declaration. Consumers that pin an
older version through an override must update or remove the override.

rules_swift 4.x requires Bazel 8 or later and Bzlmod; WORKSPACE dependency management is no longer
supported. The `swift.vfs_overlay` feature was removed. Use `swift.use_explicit_swift_module_map`
instead if you previously enabled it. See the [upstream release notes] for details.

The dependency upgrade does not enable explicit modules automatically. Existing builds continue
to use their configured features.

## Trying explicit modules

To enable explicit Clang modules for Swift compilation, add these lines to your `.bazelrc`:

```text
build --features=swift.emit_c_module --host_features=swift.emit_c_module
build --features=swift.use_c_modules --host_features=swift.use_c_modules
```

rules_swift supplies SDK module dependencies by default through its
`swift.add_default_precompiled_modules` feature. This mode does not require RSPM to generate
additional SDK dependencies. It can build more SDK modules than the package actually imports.

You can additionally enable explicit Swift module maps:

```text
build --features=swift.use_explicit_swift_module_map --host_features=swift.use_explicit_swift_module_map
```

The [explicit modules example] exercises a generated Swift library, an Objective-C dependency,
and a generated resource accessor in a macOS application bundle with implicit modules, explicit
Clang modules, and explicit Swift module maps. Run `./do_test` from its directory on macOS with
Xcode selected.

SDK selection, excluded SDK modules, compiler compatibility, and application-extension flags are
described in the [upstream explicit modules guide]. SDK configuration must be supplied by the root
Bazel module. The default SDK selection includes macOS, iOS device, and iOS simulator.

rules_swift's own SDK module exclusions do not apply to your module. Setting `exclude_modules`
replaces rules_swift's built-in defaults, so restate any default you still need. With Xcode 27,
exclude `MobileGestaltPrivate` from each SDK you build for. Add a `bazel_dep` on `rules_swift` and
use its repository name in the label:

```starlark
system_sdk = use_extension("@rules_swift//swift:extensions.bzl", "system_sdk")
system_sdk.configure_sdks(
    exclude_modules = {
        "MacOSX": ["MobileGestaltPrivate"],
        "iPhoneOS": ["MobileGestaltPrivate"],
        # CoreAudio_Private is a rules_swift default for this SDK.
        "iPhoneSimulator": ["CoreAudio_Private", "MobileGestaltPrivate"],
    },
)
```

Xcode versions before 26.4 need more exclusions. See the [rules_swift `MODULE.bazel`] for the
current list.

The [dependency inference configuration](dependency_inference.md) reserves opt-in settings for
future inference; these settings do not generate dependencies yet.

This change does not infer SDK dependencies or dependencies between binary targets. If you disable
`swift.add_default_precompiled_modules`, you must supply the required SDK dependencies yourself.
Binary frameworks with missing dependencies still need `swift_deps.configure_package(target_deps =
...)`, including in the default SDK mode. See [modifying generated targets] and the upstream guide.

[upstream release notes]: https://github.com/bazelbuild/rules_swift/releases/tag/4.0.1
[upstream explicit modules guide]: https://github.com/bazelbuild/rules_swift/blob/4.2.1/doc/explicit_modules.md
[rules_swift `MODULE.bazel`]: https://github.com/bazelbuild/rules_swift/blob/4.2.1/MODULE.bazel#L202-L253
[explicit modules example]: /examples/explicit_modules_example
[modifying generated targets]: /README.md#optional-add-dependencies-to-generated-swift-package-targets
