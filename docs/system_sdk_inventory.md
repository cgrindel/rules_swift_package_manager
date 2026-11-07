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
    developer_dir = "/Applications/Xcode.app/Contents/Developer",
    targets = {
        "MacOSX": "arm64-apple-macosx14.0",
        "iPhoneSimulator": "arm64-apple-ios17.0-simulator",
    },
    defines = [],
)
use_repo(sdk_inventory, "rspm_sdk_inventory")
```

There may be one configuration tag, owned by the root module. On macOS, set
`developer_dir` or `DEVELOPER_DIR`; if both are set they must agree. There is no
implicit `xcode-select` fallback: subprocess output is not a tracked repository
input. To follow the system selection, run `export DEVELOPER_DIR="$(xcode-select -p)"`
before invoking Bazel. Its value is tracked with `repository_ctx.getenv`. Custom
`TOOLCHAINS` selections are unsupported. Only that Xcode's SDK repository
is read, even if the upstream hub lists other installed Xcodes. Configure extra
SDKs with rules_swift's `system_sdk.configure_sdks` as well.

`targets` maps SDK names to exact Swift target triples. Match the compiler,
architecture, SDK, deployment target and additional conditional defines used by
builds. These are explicit fetch-time inputs, not values recovered from Bazel's
`--xcode_version`, transitions or arbitrary `--swiftcopt` flags. Unlisted build
configurations are unsupported; use manual dependencies or disable inference for
those packages. Apple compiler scans require a macOS fetch host. On Linux and
other non-macOS fetch hosts, the provider exports an empty inventory with a
diagnostic; Apple inference is a no-op and does not fetch Xcode or invoke swiftc.
This supports cross-platform packages built natively on Linux, not cross-compiling
Apple targets from a Linux fetch host.

Only **one target triple per SDK** is supported. An arm64 macOS profile does not
cover the x86_64 slice of a universal build, and an arm64 simulator profile does
not cover x86_64 simulators. Use separate profile configurations or disable
inference for packages that must build for multiple CPUs of the same SDK.
The consumer adds a profile guard that fails analysis when the selected Xcode,
CPU, SDK or device/simulator environment is not covered. Deployment versions and
arbitrary Swift flags still must be matched by the user; the guard cannot compare
all compiler options with repository-time profiles.

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
- `scan.inputs_digest`: a content fingerprint of the watched SDK/compiler inputs,
  including logical paths, symlink destinations and directory membership,
  calculated once in this shared repository rather than once per package.
- `scan.guard`: a dependency label that rejects unconfigured Apple build profiles.
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

The temporary adapter parses rules_swift's generated hub and selected-Xcode BUILD
files. Parsing, repository I/O and pure output rendering are separate. Tests cover
captured rules_swift 4.2.1/4.2.2 output, harmless comments/metadata, exact rendering,
and leaving an unrelated Xcode repository unread. Unsupported layouts and missing
required aliases fail with a diagnostic, rather than silently disabling inference.
Canonical sibling-repository naming remains an upstream compatibility limitation;
replacement hubs are unsupported. This adapter works with released rules_swift;
no upstream change is required. A supported upstream metadata interface could
replace the BUILD parsing and canonical-name assumptions in the future.
