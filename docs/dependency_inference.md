# Dependency inference

Source inference requires the SDK inventory provider and configured compiler
profiles. Enabling inference without that provider fails with a diagnostic.

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

## Generate and commit compiler prescans

Configure the [SDK cache provider](system_sdk_inventory.md), then generate SDK
availability and source prescans explicitly:

```sh
bazel run @rules_swift_package_manager//swiftpkg:update_sdk_cache --xcode_version=27.0 -- \
  --request sdk_profiles.json --package . --output sdk_cache.json
```

The Go tool uses the configured Xcode toolchain. It asks SwiftPM for the root
package's dependency graph and evaluates each package's manifest/description,
then runs `swiftc -frontend -scan-dependencies -import-prescan` for Swift source
targets. Existing `Package.resolved` pins are enforced. Sources may be downloaded
by this explicit command. The target depends on neither generated package
repositories nor the cache it creates, so it can bootstrap a missing cache.

Swift evaluates `#if`, `#elseif`, `#else`, `os`, `arch`, `targetEnvironment`,
`canImport`, and compiler/language-version checks. Scans apply manifest settings,
default traits, language modes, product module aliases and the platform-specific
transitive module closure. Each SDK/configuration has its own result; identical
debug/fastbuild requests share one invocation. Scans are sequential during
explicit generation, never during repository fetching.

Package modules are visible through `-module-can-import`, without building them.
Missing package-module versions retain SwiftPM's warning and unversioned behavior
for version-qualified `canImport`. Warnings use portable paths and appear in
`sdk_inference.json`.

Commit the cache. Changed settings, package manifests, source lists, source bytes
or expected compiler arguments reject stale results with a regeneration diagnostic.
Source checksums use Bazel's native local file downloader, with no subprocess or
network request. The canonical ID includes the exact current source contents so
its download cache cannot hide an edited file behind a previously verified digest.
Temporary verified copies are deleted. Compiler/SDK compatibility belongs to the
separate build-time cache-validation test, not fetching.

Profiles cannot observe arbitrary Bazel flags or transitions. Unsupported unsafe
Swift flags, C++ interop configuration and generated sources still require manual
SDK deps with inference disabled. Custom module maps and aliases must agree with
the generated package metadata; argument validation rejects mismatches. Generate
from matching patched sources for patched packages: checksums intentionally reject
caches generated from unpatched checkouts.

This moves SDK discovery, hashing and Swift prescans out of loading. Existing
SwiftPM manifest calls elsewhere remain until the wider v2 cache migration.

## Generated SDK dependencies

Swift and Clang targets receive `@system_sdk//:Module` dependencies under SDK,
platform and configuration selects. Package-provided modules are excluded using
the resolved product/target graph, including conditional edges and actual Clang
module-map names. XCTest and Testing can be inferred for package helper libraries.

The C/Objective-C parser remains a pure source-reading operation. It handles
framework imports/includes and common SDK header families such as Dispatch,
ObjectiveC, Darwin and SQLite. It does not run a C preprocessor or scan binary
artifacts. Resource accessors add Foundation. Manifest `linkedFramework` conditions
intersect SDK availability. Existing normalization merges source, manifest and
manual dependencies while preserving `select()` coverage and specialization.

`sdk_inference.json` records sources, imports, frameworks, warnings and profiles.
Committed cache JSON contains no canonical repository names or absolute Xcode
paths. The provider resolves portable IDs through the current repository mapping.
Changing the committed cache invalidates consumers; installing another Xcode alone
does not refetch them. Run the validation test in Apple CI.

Include a MacOSX profile for exec tools/macros, and separate device and simulator
profiles where needed. The guard rejects unmatched Apple configurations. Where
blanket/manual dependencies cover them, set
`--@rules_swift_package_manager//config_settings/sdk_inference:strict_profile=false`.
This only relaxes the guard. Linux matches no Apple SDK conditions and is allowed
by the guard. Deployment versions and arbitrary compiler flags still need to match.

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
