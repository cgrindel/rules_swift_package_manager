# Committed SDK cache and compiler profiles

SDK metadata is generated explicitly with a Bazel-built Go tool and committed to
source control. The inventory repository only reads declared JSON labels. It does
not run Python, Swift, xcrun, or any other subprocess; inspect the host SDK; or read
host environment variables. This follows the loading-phase direction in
[#2641](https://github.com/cgrindel/rules_swift_package_manager/issues/2641).

This provider alone does not infer package dependencies. The source-inference
consumer lands after it. Existing SwiftPM manifest evaluation elsewhere in RSPM
has not been migrated by this change.

## Generate and configure

Create `sdk_profiles.json` in your workspace:

```json
{
  "targets": {
    "MacOSX": "arm64-apple-macosx14.0",
    "iPhoneSimulator": "arm64-apple-ios17.0-simulator"
  },
  "defines": [],
  "exclude_modules": {}
}
```

Match the SDK exclusions in rules_swift's `system_sdk.configure_sdks` (including
its defaults). The example shows exclusions for the SDKs shipped with Xcode 27.
Then run:

```sh
bazel run @rules_swift_package_manager//swiftpkg:update_sdk_cache --xcode_version=27.0 -- \
  --request sdk_profiles.json --output sdk_cache.json
```

The runnable target obtains the compiler from the configured rules_swift
toolchain. An apple_support action resolves the Developer directory for Bazel's
selected Xcode; `xcrun` is used only within that selection during explicit
execution. The tool does not select a compiler from `PATH`. No installed Go or
Python is required: rules_go builds the generator using its downloaded SDK.
Generation currently supports Xcode toolchains on macOS.

Commit the settings and generated cache. Declare both source files in your BUILD
file with `exports_files`, and configure the root module:

```starlark
sdk_inventory = use_extension(
    "@rules_swift_package_manager//:extensions.bzl",
    "sdk_inventory",
)
sdk_inventory.configure(
    cache = "//:sdk_cache.json",
    request = "//:sdk_profiles.json",
)
use_repo(sdk_inventory, "rspm_sdk_inventory")
```

Only the root module can configure the cache. The repository is lazy and is read
only by opted-in package repositories before package downloads and SwiftPM work.
A missing cache or changed settings fail with a regeneration command. There is
no repository-time fallback to generating it.

The generator does not depend on `@rspm_sdk_inventory`, the existing cache, or
generated package repositories. It can therefore create the first cache and
repair an invalid one. Re-run generation after changing Xcode, profiles or SDK
exclusions. Output is atomically replaced only after all scans succeed.

## Validate the current toolchain

Loading validates the cache schema, declared generation settings and availability
references. It deliberately does not check the current machine's compiler or SDK.
Use a build-time test for that check:

```starlark
load("@rules_swift_package_manager//swiftpkg:sdk_cache.bzl", "swift_sdk_cache_test")

swift_sdk_cache_test(
    name = "sdk_cache_test",
    cache = "sdk_cache.json",
    target_compatible_with = ["@platforms//os:macos"],
)
```

Alternatively, run the generator with `--validate sdk_cache.json`. Validation
compares compiler/Xcode stamps and input fingerprints without rewriting the cache.
Run it in Apple CI before relying on cached inference.

Default fingerprinting covers the compiler binary, Xcode `version.plist`, and
SDK `SDKSettings.json` files. It assumes an unmodified Xcode installation. Set
`"full_sdk_tracking": true` in the settings to hash SDK and toolchain contents
for SDK development. This cost occurs during explicit generation/validation,
never repository fetching. Fingerprints use logical relative names, so relocating
an unchanged installation does not invalidate them.

## Profiles and portability

- Profiles specify one exact target triple per SDK. An arm64 profile does not
  cover x86_64 or a universal build's other slice.
- Include a `MacOSX` profile for exec tools and macros, even in iOS package graphs.
- Simulator profiles do not cover device builds. Add `iPhoneOS` for archives.
- Match conditional defines and deployment targets with the build. Repository
  rules cannot observe arbitrary compiler flags or transitions.
- Fetching uses the same committed cache on Linux and macOS. Apple conditions do
  not match Linux, and the profile guard permits Linux builds.

The `@rspm_sdk_inventory//:scan_profile` guard rejects unmatched Apple Xcode, CPU
and SDK configurations. Where blanket or manual SDK dependencies cover an
unmatched configuration, opt out with:

```text
--@rules_swift_package_manager//config_settings/sdk_inference:strict_profile=false
```

This relaxes the guard only; it does not add missing dependencies. Deployment
versions and arbitrary compiler options are not checked by the guard.

## Cache contract

Committed schema 3 contains generation settings, exact Xcode and Swift versions,
SHA-256 input fingerprints, and module names mapped to SDK IDs. It contains no
absolute installation paths or canonical Bazel repository names. SDK discovery
and compiler dependency scanning run in Go during explicit generation, not by
parsing rules_swift BUILD files during fetching.

The provider renders public platform/configuration conditions and the guard from
those portable IDs. Canonical labels occur only in its generated `modules.json`,
resolved through the current repository mapping. Changing the committed cache
invalidates its consumers; installing or switching Xcode alone does not refetch
packages. rules_swift still supplies the actual `@system_sdk` build targets, and
its own SDK repository implementation is outside this change's scope.
