# SDK inventory and compiler profiles

The SDK provider supplies metadata for compiler-driven dependency inference. It
alone neither scans package sources nor adds dependencies. It is lazy: disabled
inference and complete BUILD overrides do not fetch it. Package repositories
resolve it before downloads and SwiftPM execution.

## Configuration

The root module must declare the configurations for which imports will be scanned:

```starlark
sdk_inventory = use_extension(
    "@rules_swift_package_manager//:extensions.bzl",
    "sdk_inventory",
)
sdk_inventory.configure(
    targets = {
        "MacOSX": "arm64-apple-macosx14.0",
        "iPhoneSimulator": "arm64-apple-ios17.0-simulator",
    },
    defines = [],
)
use_repo(sdk_inventory, "rspm_sdk_inventory")
```

There may be one configuration tag, owned by the root module. Keep machine-specific
paths out of `MODULE.bazel`. On macOS, select Xcode in your machine-local Bazel rc
file (imported by the project's `.bazelrc`), using the installed path and matching
version:

```text
common --repo_env=DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
build --xcode_version=27.0.0
```

`--xcode_version` must select the same Xcode as `DEVELOPER_DIR`. Alternatively,
export `DEVELOPER_DIR="$(xcode-select -p)"` before invoking Bazel and set the matching
`--xcode_version`. There is no implicit `xcode-select` fallback: subprocess output
is not a tracked repository input. The provider tracks `DEVELOPER_DIR` through
`repository_ctx.getenv`. An explicit `developer_dir` configuration attribute is
also supported for controlled environments; if both inputs are set they must
agree. Custom `TOOLCHAINS` selections are unsupported. Only that Xcode's SDK
repository is read, even if the upstream hub lists other installed Xcodes.
Configure extra SDKs with rules_swift's `system_sdk.configure_sdks` as well.

`targets` maps SDK names to exact Swift target triples. Match the compiler,
architecture, SDK, deployment target and additional conditional defines used by
builds. These are explicit fetch-time inputs, not values recovered from Bazel's
`--xcode_version`, transitions or arbitrary `--swiftcopt` flags. Unlisted build
configurations have no inferred dependencies; see the strict profile guard below. Apple compiler scans require a macOS fetch host. On Linux and
other non-macOS fetch hosts, the provider exports an empty inventory with a
diagnostic; Apple inference is a no-op and does not fetch Xcode or invoke swiftc.
This supports cross-platform packages built natively on Linux, not cross-compiling
Apple targets from a Linux fetch host.

Only **one target triple per SDK** is supported. An arm64 macOS profile does not
cover the x86_64 slice of a universal build, and an arm64 simulator profile does
not cover x86_64 simulators. Separate single-CPU builds can each use a matching
profile configuration.

Profiles must cover **exec configurations** as well as application targets. Package
graphs containing Swift macros or build tools (for example, swift-syntax macros or
protoc-gen-swift) generally need a `MacOSX` profile matching the execution platform,
even for iOS-only applications. A simulator profile does not cover device builds
or archives: add an `iPhoneOS` profile for those builds.

By default, the consumer's guard fails analysis if the selected Xcode, CPU, SDK or
device/simulator environment is not covered. For configurations that retain
rules_swift's blanket SDK dependencies or supply complete manual dependencies,
you can explicitly permit unmatched profiles:

```text
build:blanket_sdk_deps --@rules_swift_package_manager//config_settings/sdk_inference:strict_profile=false
```

The flag only relaxes the guard; it does **not** add missing dependencies or turn
on blanket SDK dependencies. Inference still applies to matching profiles, and
unmatched profiles contribute no inferred SDK dependencies. This lets universal
macOS, other simulator architectures, exec tools or device builds use blanket or
manual dependencies without being rejected by the guard. Keep strict checking
where inference is required for correctness. Disabling `system_sdk_deps` for a
package remains an alternative. Deployment versions and arbitrary Swift flags
still must be matched by the user; the guard cannot compare all compiler options
with repository-time profiles.

Profiles validate the target's OS and device/simulator environment against its SDK
before fetching upstream SDK metadata. Supported scan CPUs are `arm64` and
`x86_64` (the latter only for macOS and simulators); other ABI variants require
their own matching Bazel constraints and are rejected.

Scans clear inherited `CPATH`, `C_INCLUDE_PATH`, `CPLUS_INCLUDE_PATH`, and
`OBJC_INCLUDE_PATH`, and use the selected default toolchain. Extra host include
paths are not supported scan inputs. The provider exports this environment for
package scans to use as well.

## Contract

`@rspm_sdk_inventory//:modules.json` has schema version 2. It contains:

- `modules`: module names mapped to SDK condition identifiers.
- `conditions`: SDK, platform, environment, and public availability labels,
  including debug, release and fastbuild conditions.
- `scan`: the selected compiler, developer directory, compiler/Xcode versions,
  SDK paths, target triples and additional defines.
- `scan.input_tracking`: `identity` (default) or `full`.
- `scan.inputs_digest`: a content fingerprint of the watched inputs, calculated
  once in this shared repository rather than once per package. Full tracking also
  includes SDK/toolchain files and directory layout.
- `scan.guard`: a dependency label that rejects unconfigured Apple build profiles
  unless `strict_profile` is disabled.
- `diagnostic`: explains skipped inference on non-macOS hosts; invalid Apple
  provider configurations fail. Skipped profiles have `scan.host_supported = False`.

SDK labels do not contain Xcode versions. Their definitions select the configured
Xcode and architecture. Compiler identity is deliberately retained in `scan`:
changing the compiler can change `#if compiler(...)` and `canImport` results and
must invalidate package scans. Other installed Xcodes are not scan inputs.

## Fetching and compatibility

This remains a host-dependent, configured compiler operation. Changing its
configuration can rerun package repository generation, including downloads; this
is not a promise of zero refetches or identical output across arbitrary hosts.
Default tracking watches and fingerprints the compiler binary, Xcode's
`Contents/version.plist` and each configured SDK's `SDKSettings.json`. Compiler
and Xcode version output, paths and profile settings also form part of the
metadata consumed by package repositories. This assumes an **unmodified Xcode
installation**: changing an SDK header, developer framework or toolchain library
without updating these identity files is not detected by default.

For in-place SDK/toolchain development, set `full_sdk_tracking = True` on
`sdk_inventory.configure(...)`. This additionally traverses and watches the
configured SDK trees, toolchain libraries and developer framework directories,
and fingerprints their files and layout. It costs substantially more at fetch
time and when revalidating repository inputs after a server restart. See the
[cold-fetch and unchanged-build measurements](sdk_inference_benchmark.md).

The temporary adapter parses rules_swift's generated hub and selected-Xcode BUILD
files. Parsing, repository I/O and pure output rendering are separate. Tests cover
captured rules_swift 4.2.1/4.2.2 output, harmless comments/metadata, exact rendering,
and leaving an unrelated Xcode repository unread. Unsupported layouts and missing
required aliases fail with a diagnostic, rather than silently disabling inference.
Canonical sibling-repository naming remains an upstream compatibility limitation;
replacement hubs are unsupported. This adapter works with released rules_swift;
no upstream change is required. A supported upstream metadata interface could
replace the BUILD parsing and canonical-name assumptions in the future.
