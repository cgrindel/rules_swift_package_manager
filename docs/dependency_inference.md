# Dependency inference

Source inference consumes the package-context inventory supplied by [#2619](https://github.com/cgrindel/rules_swift_package_manager/pull/2619).
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

## SDK dependency generation

When enabled, generated Swift and Clang targets receive `@system_sdk//:Module`
dependencies wrapped in platform selects with an empty default for other
platforms. The scan includes unconditional Swift imports, import attributes,
scoped imports such as `import struct Darwin.stat`, and non-framework modules
such as `Darwin` and `Dispatch`. It ignores Swift comments and string literals.
The scanner evaluates `os(...)`, `targetEnvironment(simulator)`, and
`canImport(Module)` when it guards an import of that same SDK module. It keeps
`#elseif` and `#else` branches distinct for each Xcode and SDK variant.
Other conditions, including custom build flags and compiler-version checks,
remain unknown and are skipped. Developer test modules such as `XCTest` and
`Testing` are not inferred for non-test targets. Supply missed dependencies
with `target_deps`.

The C/Objective-C scan uses the existing framework import parser for `@import`,
`#import <Framework/Header.h>` and `#include <Framework/Header.h>`. It reads the
target's discovered source files and headers, removes comments and quoted/raw
string and character literals, and ignores quoted local includes. It does not recursively follow external headers or map
arbitrary C header names to SDK modules. Generated resource accessors also add
Foundation. Binary artifacts are not scanned.

Manifest framework platform and debug/release conditions are intersected with
SDK availability. Source and manifest dependencies are deduplicated, and manual
`target_deps` remain additive. Existing target-attribute replacements run last
and can replace the complete generated dependency list. Additive overrides do
not duplicate a dependency already supplied by inference. For referenced external
products, inference reads each declared dependency's exported `pkg_info.json` once
and follows the product's local target graph to exclude its actual module names.
Product results are cached per package, product and SDK platform. Exclusions
retain platform conditions on both product references and local target edges,
and use Clang module-map names when those differ from target names. Unrelated
local targets do not suppress SDK imports. Unknown modules are
skipped; supply missed dependencies with `target_deps` or disable inference for
a package with `system_sdk_deps = "off"`.

## SDK inventory and configuration

RSPM imports `system_sdk` into its own repository mapping so that generated
labels resolve without a root `use_repo` declaration. The consuming root module
still owns SDK selection and exclusions. Configure extra SDKs with rules_swift's
`system_sdk.configure_sdks`; importing the repository does not enable them.

The shared, lazy [SDK inventory adapter](https://github.com/cgrindel/rules_swift_package_manager/pull/2619) provides
per-Xcode and per-SDK availability. It documents the metadata schema, upstream
BUILD-format coupling and host-dependent fetching behavior. Inference reads it
before invoking SwiftPM and resolves only the modules encountered by a target.
Disabled inference and complete BUILD overrides do not fetch the inventory.
Unsupported layouts produce a warning and a persisted diagnostic included in
generated BUILD comments; use `target_deps` in that case.

See the [source inference integration example](../examples/explicit_modules_example) and
[original proposal](https://github.com/cgrindel/rules_swift_package_manager/discussions/2488).
