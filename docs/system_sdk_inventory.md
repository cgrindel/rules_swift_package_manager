# SDK inventory and compiler profiles

The SDK inventory is a repository, `@rspm_sdk_inventory`, that records which Apple SDK modules the
selected Xcode provides for each configured compiler profile. A compiler profile is an SDK name
paired with the exact Swift target triple used to build for it. Source dependency inference will
read the inventory to decide which SDK modules a package needs.

In this release, the inventory changes no generated dependencies. Turning on `system_sdk_deps` only
fetches it, and that fetch requires the setup below. See
[dependency inference](dependency_inference.md) for the `system_sdk_deps` setting.

The inventory is fetched only by package repositories that have `system_sdk_deps` enabled and no
complete BUILD file override. Those repositories fetch it before downloading sources or running
SwiftPM.

## Setup

Declare the compiler profiles in the root module. Only the root module may configure the inventory,
and only with one `configure` tag:

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

`targets` maps SDK names to exact Swift target triples. Match the CPU, SDK, deployment target and
conditional compilation `defines` that your builds use. The inventory cannot read these from Bazel's
flags, transitions or `--swiftcopt` values.

Select Xcode explicitly. The inventory does not fall back to `xcode-select`, because the output of a
subprocess is not a tracked repository input. Either export `DEVELOPER_DIR` before running Bazel:

```sh
export DEVELOPER_DIR="$(xcode-select -p)"
```

and forward it from your `.bazelrc` with `common --repo_env=DEVELOPER_DIR`, or set the path in a
machine-local Bazel rc file that your `.bazelrc` imports:

```text
common --repo_env=DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Bazel must build with the same Xcode. Its default Xcode configuration uses the `xcode-select` Xcode.
If you set `--xcode_version`, it must match `DEVELOPER_DIR`. The `developer_dir` attribute of
`sdk_inventory.configure` is an alternative for controlled environments; if both it and
`DEVELOPER_DIR` are set, they must agree.

Each configured SDK must also be enabled in rules_swift's `system_sdk.configure_sdks`.

On macOS, fetching the inventory runs `xcrun`, `xcodebuild`, `swiftc --version` and
`/usr/bin/python3`.

## Limitations

- **macOS fetch hosts only.** On Linux and other hosts, the inventory is empty and contains a
  diagnostic. It does not look for Xcode or run any tools. This supports cross-platform packages
  built natively on Linux, not cross-compiling Apple targets from Linux.
- **One target triple per SDK.** An arm64 macOS profile does not cover the x86_64 slice of a
  universal build, and an arm64 simulator profile does not cover x86_64 simulators. Separate
  single-CPU builds can each use a matching profile.
- **Supported CPUs.** Profiles may use `arm64`, or `x86_64` for macOS and simulators. Device SDKs
  other than macOS require `arm64`. Other CPUs and ABI variants are rejected.
- **Exec configurations need profiles too.** Package graphs with Swift macros or build tools, such
  as swift-syntax macros or `protoc-gen-swift`, generally need a `MacOSX` profile that matches the
  execution platform, even for iOS-only applications.
- **Simulator profiles do not cover devices.** Add an `iPhoneOS` profile for device builds and
  archives.
- **Default toolchain only.** Custom `TOOLCHAINS` selections are rejected. Scans clear `CPATH`,
  `C_INCLUDE_PATH`, `CPLUS_INCLUDE_PATH`, `OBJC_INCLUDE_PATH`, `SDKROOT`, `CLANG_MODULE_CACHE_PATH`
  and `SWIFT_MODULECACHE_PATH`, and force the default Xcode toolchain. Extra host include paths are
  not supported. The inventory records this environment so package scans can use it.
- **Only the selected Xcode is read.** Other installed Xcodes in rules_swift's SDK hub are ignored.

Profiles are checked against their SDK's OS and device or simulator environment before any SDK
metadata is read.

## Profile guard

The inventory exports a guard, `@rspm_sdk_inventory//:scan_profile`. It fails analysis when the
build's Xcode, CPU, SDK or device/simulator environment matches no configured profile. In this
release no generated target depends on the guard, so it only fails when built directly. Source
dependency inference will add it to the targets that rely on inferred SDK dependencies.

Builds that keep rules_swift's blanket SDK dependencies, or that supply complete manual
dependencies, can permit unmatched profiles:

```text
build:blanket_sdk_deps --@rules_swift_package_manager//config_settings/sdk_inference:strict_profile=false
```

The flag only relaxes the guard. It does **not** add missing dependencies or turn on blanket SDK
dependencies. Matching profiles still get inferred dependencies, and unmatched profiles get none.
This lets universal macOS builds, other simulator CPUs, exec tools and device builds rely on blanket
or manual dependencies without being rejected. Keep strict checking where inference is required for
correctness, or disable `system_sdk_deps` for the affected package. The guard cannot compare
deployment versions or arbitrary Swift flags, so those must still match the profiles.

## Contract

`@rspm_sdk_inventory//:modules.json` has schema version 2. It contains:

- `modules`: each module name mapped to the SDK names that provide it, for example
  `"Foundation": ["MacOSX"]`. Each SDK name is a key in `conditions`.
- `conditions`: for each SDK, its platform, device or simulator environment, and public condition
  labels, including debug, release and fastbuild variants.
- `scan`: the selected compiler, developer directory, compiler and Xcode versions, SDK paths, target
  triples, additional defines and scan environment.
- `scan.input_tracking`: `identity` (the default) or `full`.
- `scan.inputs_digest`: a content fingerprint of the watched inputs, calculated once in the shared
  repository rather than once per package. Full tracking also includes SDK and toolchain files and
  their directory layout.
- `scan.guard`: the profile guard label.
- `diagnostic`: why inference is skipped, on non-macOS hosts. Those hosts also set
  `scan.host_supported = False`. Invalid configurations on macOS fail instead.

SDK condition labels do not contain Xcode versions; their definitions select the configured Xcode
and CPU. The compiler identity is deliberately kept in `scan`, because changing the compiler can
change `#if compiler(...)` and `canImport` results and must invalidate package scans. Other
installed Xcodes are not scan inputs.

## Fetching and compatibility

The inventory depends on the host and its configured compiler. Every package repository with
`system_sdk_deps` enabled reads `modules.json`, so changing Xcode, `DEVELOPER_DIR` or the profiles
refetches all of those repositories, including their downloads. This happens even in this release,
where the inventory changes no generated dependencies.

By default, the inventory watches and fingerprints the compiler binary, Xcode's
`Contents/version.plist` and each configured SDK's `SDKSettings.json`. Compiler and Xcode version
output, paths and profile settings are also part of `modules.json`. This assumes an **unmodified
Xcode installation**: changing an SDK header, developer framework or toolchain library without
changing these files is not detected.

For in-place SDK or toolchain development, set `full_sdk_tracking = True` on
`sdk_inventory.configure(...)`. This also traverses and watches the configured SDK trees, toolchain
libraries and developer framework directories, and fingerprints their files and layout. It costs
substantially more at fetch time and when Bazel revalidates repository inputs after a server
restart.

The inventory reads rules_swift's generated SDK BUILD files and relies on their canonical repository
names. Replacement `system_sdk` hubs are not supported. Unsupported layouts and missing aliases fail
with a diagnostic instead of silently disabling inference.
