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
`bazel_target_set_*` and `bazel_target_add*` modifications still run last. Inference
configuration does not conflict with either mechanism, and does not change the
existing conflict between a full BUILD override and target modifications.

## SDK dependency generation

When enabled, generated Swift and Clang targets receive `@system_sdk//:Module`
dependencies wrapped in platform selects with an empty default for other
platforms. The scan includes conditional Swift imports, import attributes,
scoped imports such as `import struct Darwin.stat`, and non-framework modules
such as `Darwin` and `Dispatch`. It ignores Swift comments and string literals.
Conditional compilation expressions are not evaluated: a conditional import can
add an unused dependency on any platform where that SDK module is available.

The C/Objective-C scan uses the existing framework import parser for `@import`,
`#import <Framework/Header.h>` and `#include <Framework/Header.h>`. It reads the
target's discovered source files and headers, removes comments, and ignores
quoted local includes. It does not recursively follow external headers or map
arbitrary C header names to SDK modules. Generated resource accessors also add
Foundation. Binary artifacts are not scanned.

Manifest framework platform and debug/release conditions are intersected with
SDK availability. Source and manifest dependencies are deduplicated, and manual
`target_deps` remain additive. Existing target-attribute replacements run last
and can replace the complete generated dependency list. Unknown modules are
skipped; supply missed dependencies with `target_deps` or disable inference for
a package with `system_sdk_deps = "off"`.

## SDK inventory and configuration

RSPM imports `system_sdk` into its own repository mapping so that generated
labels resolve without a root `use_repo` declaration. The consuming root module
still owns SDK selection and exclusions. Configure extra SDKs with rules_swift's
`system_sdk.configure_sdks`; importing the repository does not enable them.

rules_swift 4.2.1 does not export a structured per-platform inventory. RSPM
therefore reads the actual generated hub and per-Xcode BUILD alias selects using
a small internal adapter. It does not use the historical framework catalog or
assume that every known module is present on every SDK. This adapter is coupled
to rules_swift's generated format; an unsupported alias shape fails with an
instruction to disable inference and use manual dependencies. A public upstream
inventory should replace it when available.

Only modules present in the hub and available in **every configured Xcode** are
inferred for a platform. On iOS, tvOS, watchOS and visionOS, both device and
simulator SDK aliases must be available; macOS requires its MacOSX alias. This
conservative intersection respects configured SDKs and exclusions, but can omit
modules available only in a newer Xcode or a single device/simulator variant.
Those dependencies can be supplied manually. No Apple dependencies are inferred
from the non-Apple host stub. Disabled inference does not read or fetch the SDK
inventory. Enabled inference reads each configured Xcode's generated BUILD file,
which can trigger rules_swift's SDK scan for that Xcode.

See the [part 3 integration example](../examples/explicit_modules_example) and
[original proposal](https://github.com/cgrindel/rules_swift_package_manager/discussions/2488).
