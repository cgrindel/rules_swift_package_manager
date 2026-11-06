# Dependency inference

Source inference consumes the package-context inventory supplied by the SDK provider.
The provider and consumer changes can merge in either order. Until the provider
is present, opting in remains a no-op; no SDK dependencies are guessed or added.

`system_sdk_deps` opts source targets into SDK dependency generation from Swift
imports, Objective-C/C imports and includes, and manifest `linkedFramework`
settings. It is off by default. `binary_target_deps` remains reserved for a
separate follow-up and does not infer dependencies yet. Compiler features remain
independently configured as described in the [migration notes](rules_swift_4_migration.md).

## Root defaults and package overrides

Only the root Bazel module can set inference policy. Both defaults are false;
at most one `configure_explicit_modules` tag is allowed:

```starlark
swift_deps.configure_explicit_modules(
    system_sdk_deps = True,
    binary_target_deps = False,
)
swift_deps.configure_package(
    name = "some-package",
    system_sdk_deps = "off",
    binary_target_deps = "on",
)
```

Each package setting accepts `"inherit"` (the default), `"on"`, or `"off"`.
`inherit` uses the corresponding root default, or false when no global tag is
present. The two settings resolve independently. Package names use the existing
`configure_package` lookup: the dependency name is tried first, then the generated
repository name (for example `swiftpkg_some_package`). When both names have
explicit overrides, the dependency-name entry wins as a whole.

Non-root modules may continue using existing package configuration, with both
inference fields left at `inherit`. A non-root global tag or an explicit package
inference override is rejected. Duplicate root `configure_package` names are
rejected, even when one tag only contains legacy settings. Add inference fields
to the existing tag alongside `build_file`, `patches`, or `target_deps`; do not
add a second tag for the same name. This ownership and duplicate-name validation
runs even if no package is fetched.

Explicit inference overrides must match a discovered dependency name or generated
repository name. Unknown names fail with a list of available names to help catch
typos. Matching includes unresolved dependencies, so a stale `Package.resolved`
does not prevent running package resolution. Both accepted names count as known
when both are configured, even though the dependency-name override takes priority.

Resolved booleans are passed to Git, local, and registry repositories and stored
in the package generation context. Direct users of `swift_package`,
`local_swift_package`, and `registry_swift_package` may supply the same boolean
attributes, which also default to false.

A complete `build_file` override still bypasses generation. Existing
`bazel_target_set_*` and `bazel_target_add*` modifications apply after inference.
SDK dependencies are then deduplicated by label identity, including canonical
and apparent SDK labels, while preserving select specialization and default
branches. Other dependencies are left untouched. Inference
configuration does not conflict with either mechanism, and does not change the
existing conflict between a full BUILD override and target modifications.

## Compiler-driven SDK dependencies

With the source-inference consumer installed, Swift imports are collected with
`swiftc -frontend -scan-dependencies -import-prescan`. Swift evaluates conditional
imports, including `#elseif`, `canImport`, compiler-version checks and custom
flags. RSPM does not implement a second Swift lexer or Boolean evaluator.

The root must configure [SDK compiler profiles](system_sdk_inventory.md), in
addition to enabling `system_sdk_deps`. The provider and source-inference
consumer are separate components; the consumer is a no-op until the provider
supplies metadata. The provider alone does not generate source dependencies.

For each target, scans use the configured compiler/SDK/target triple, root
conditional defines, SwiftPM defines, traits, language mode, upcoming/experimental
features and module aliases. Debug, release and fastbuild are scanned separately;
identical command lines share results. Known dependency module names are supplied
to `-module-can-import`, without building those dependencies. This supplies name
availability, not package module versions or validation of their implementations.
Sources containing version-qualified `canImport` checks are conservatively
rejected because package module version metadata is unavailable. This safeguard
can also reject comments mentioning those checks; use manual dependencies. SDK availability comes from the compiler's search paths.
Developer framework search paths match generated libraries; test helper libraries
can therefore infer XCTest and Testing without a blanket non-test exclusion.

This is a bounded fetch-time operation. It cannot observe arbitrary Bazel
`--swiftcopt` values, target transitions or later attribute overrides. Profiles
must match builds; disable inference for packages that need other configurations.
Unsafe Swift manifest flags are rejected rather than silently interpreted in a
different environment. Scan errors fail with the target and SDK/configuration.
Generated sources and plugin-generated imports are not covered. Only the direct
Swift imports are prescanned; the existing SDK targets supply their transitive
SDK dependencies. This is not a full compiler dependency graph or dynamic Bazel
dependency discovery.

The C/Objective-C scan handles framework imports and includes, removes comments
and literals, and ignores quoted local includes. It maps common SDK headers such
as `dispatch/dispatch.h`, `objc/runtime.h`, `sqlite3.h`, standard C headers and
`sys/...` to their SDK modules. Arbitrary external headers are not recursively
scanned, and C preprocessor conditions are not evaluated. Binary artifacts are
not scanned. Generated resource accessors add Foundation.

Manifest `linkedFramework` settings preserve platform and build-configuration
conditions. SDK dependencies are deduplicated, including after target overrides,
without changing select exclusions/defaults or unrelated dependencies. Package
module names are resolved through their dependency products, preserving platform
conditions and actual Clang module-map names.

`sdk_inference.json` in each scanned package repository records compiler profiles,
source files, discovered Swift imports by configuration and manifest frameworks.
The compiler reports imports for the whole source module, not per-import line
locations.
Compiler and SDK paths used for scanning are watched and fingerprinted once by
the shared provider; package repositories read that fingerprint. Configuration changes can
rerun package generation; this does not promise identical outputs across hosts
with different toolchains or eliminate all repository refetches.

## Manual dependencies

Use `target_deps` for dependencies valid in every configuration that builds a
target. For platform-specific SDK modules, use an additive select instead:

```starlark
swift_deps.bazel_target_add_select(
    target = "@swiftpkg_example//:Example.rspm.__impl",
    attr = "deps",
    values = {"@@platforms//os:ios": ["@system_sdk//:UIKit"]},
)
```

The empty default is supplied automatically. Additional SDK/Xcode constraints
may be needed for modules with narrower availability. An unconditional UIKit
`target_deps` entry is not valid for a target also built on macOS; inference does
not reinterpret an explicit unconditional dependency as conditional. Replacing
`deps` remains available when the complete dependency list is known.

See the [integration example](../examples/explicit_modules_example) and
[original proposal](https://github.com/cgrindel/rules_swift_package_manager/discussions/2488).
