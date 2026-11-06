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

There may be one configuration tag, owned by the root module. `developer_dir`
defaults to `DEVELOPER_DIR`, then `xcode-select`. If set explicitly, it must match
that environment so the upstream hub and this adapter use the same Xcode. Custom
`TOOLCHAINS` selections are unsupported. Only that Xcode's SDK repository
is read, even if the upstream hub lists other installed Xcodes. Configure extra
SDKs with rules_swift's `system_sdk.configure_sdks` as well.

`targets` maps SDK names to exact Swift target triples. Match the compiler,
architecture, SDK, deployment target and additional conditional defines used by
builds. These are explicit fetch-time inputs, not values recovered from Bazel's
`--xcode_version`, transitions or arbitrary `--swiftcopt` flags. Unlisted build
configurations are unsupported; use manual dependencies or disable inference for
those packages. Apple compiler scans require a macOS fetch host. Vendored SDK
BUILD files alone cannot run the compiler on Linux.

## Contract

`@rspm_sdk_inventory//:modules.json` has schema version 2. It contains:

- `modules`: module names mapped to SDK condition identifiers.
- `conditions`: SDK, platform, environment, and public availability labels,
  including debug, release and fastbuild conditions.
- `scan`: the selected compiler, developer directory, compiler/Xcode versions,
  SDK paths, target triples and additional defines.
- `scan.inputs_digest`: a content fingerprint of the watched SDK/compiler inputs,
  calculated once in this shared repository rather than once per package.
- `diagnostic`: reserved for diagnostics; invalid provider configurations fail.

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
replacement hubs are unsupported. A supported upstream metadata interface should
replace this adapter. Compiler scanning itself does not require that interface,
but mapping SDK imports to existing Bazel targets still needs a supported contract.
