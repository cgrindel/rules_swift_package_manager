# Dependency inference

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
Dependency expressions are then deduplicated without changing which labels each
select contributes, including specialization and default branches. Inference
configuration does not conflict with either mechanism, and does not change the
existing conflict between a full BUILD override and target modifications.

## SDK dependency generation

When enabled, generated Swift and Clang targets receive `@system_sdk//:Module`
dependencies wrapped in platform selects with an empty default for other
platforms. The scan includes unconditional Swift imports, import attributes,
scoped imports such as `import struct Darwin.stat`, and non-framework modules
such as `Darwin` and `Dispatch`. It ignores Swift comments and string literals.
Imports inside any `#if` branch are skipped: repository evaluation cannot safely
evaluate Swift conditions, and adding a module can itself change `canImport`.
Supply dependencies for conditional imports with `target_deps`.

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
This avoids assuming a product name is its module name. Unknown modules are
skipped; supply missed dependencies with `target_deps` or disable inference for
a package with `system_sdk_deps = "off"`.

## SDK inventory and configuration

RSPM imports `system_sdk` into its own repository mapping so that generated
labels resolve without a root `use_repo` declaration. The consuming root module
still owns SDK selection and exclusions. Configure extra SDKs with rules_swift's
`system_sdk.configure_sdks`; importing the repository does not enable them.

rules_swift 4.2.1 does not export a structured per-platform inventory. A shared,
lazily fetched RSPM repository reads the generated hub and per-Xcode BUILD files
once and exports compact metadata. Package repositories read that JSON instead
of reparsing each full SDK BUILD file. With inference disabled, this repository
is not fetched.

The metadata preserves each hub Xcode selector and SDK variant separately.
Device-only modules remain eligible for device builds; a module available in a
newer Xcode is not removed because another Xcode lacks it. The shared repository
copies the SDK settings' actual constraints because upstream keeps those
settings private. Generated selects combine those constraints with the hub's
public Xcode selector, so build-time Xcode selection remains with Bazel.

The adapter still depends on rules_swift's generated format and standard
extension repository layout. Unsupported formats or replacement hub repositories
emit a warning and disable the entire inferred inventory; use `target_deps` in
that case. No partial inventory or guessed universal framework catalog is used.
An upstream structured inventory should replace this adapter when available.

Reading the shared inventory can fetch and scan every Xcode referenced by the
hub, once per SDK repository. Consumers needing a stable, limited inventory can
use rules_swift's root `system_sdk.configure_xcode` with a precomputed BUILD;
RSPM honors those hub entries. Module extensions cannot observe the build-time
`--xcode_version` flag, so RSPM does not choose a build Xcode at repository time.
SDK metadata changes still invalidate the shared inventory and its consumers.
No Apple dependencies are inferred from the non-Apple host stub.

See the [part 3 integration example](../examples/explicit_modules_example) and
[original proposal](https://github.com/cgrindel/rules_swift_package_manager/discussions/2488).
