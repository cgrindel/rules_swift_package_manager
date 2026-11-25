# Swift Package Manager Rules for Bazel

[![Build](https://github.com/cgrindel/rules_swift_package_manager/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/cgrindel/rules_swift_package_manager/actions/workflows/ci.yml)

This repository contains a Bazel ruleset that can be used to download, build, and consume Swift
packages. The rules in this repository build the external Swift packages using [rules_swift],
[rules_apple] and native C/C++ rulesets making the Swift package products and targets available as
Bazel targets.

This repository is designed to fully replace [rules_spm] and provide utilities to ease Swift
development inside a Bazel workspace.

## Table of Contents

<!-- MARKDOWN TOC: BEGIN -->
* [Documentation](#documentation)
* [Prerequisites](#prerequisites)
  * [Mac OS](#mac-os)
  * [Linux](#linux)
* [Quickstart](#quickstart)
  * [1. Enable bzlmod](#1-enable-bzlmod)
  * [2. Configure your `MODULE.bazel` to use rules_swift_package_manager.](#2-configure-your-modulebazel-to-use-rules_swift_package_manager)
    * [(Optional) Configure the `swift package` flags](#optional-configure-the-swift-package-flags)
    * [(Optional) Add dependencies to generated Swift package targets](#optional-add-dependencies-to-generated-swift-package-targets)
    * [(Optional) Override attributes on generated Bazel targets](#optional-override-attributes-on-generated-bazel-targets)
  * [3. Create a minimal `Package.swift` file.](#3-create-a-minimal-packageswift-file)
  * [4. Create a slice with `init`.](#4-create-a-slice-with-init)
  * [5. Run `bazel mod tidy`.](#5-run-bazel-mod-tidy)
  * [6. Run `bazel run @swift_package//:resolve`.](#6-run-bazel-run-swift_packageresolve)
  * [7. Run `bazel mod tidy` again.](#7-run-bazel-mod-tidy-again)
  * [8. Build and test your project.](#8-build-and-test-your-project)
  * [9. Check in your files.](#9-check-in-your-files)
  * [10. Start coding](#10-start-coding)
* [Updating Swift packages](#updating-swift-packages)
* [Slices](#slices)
  * [Swift version check](#swift-version-check)
* [Using a Swift package registry](#using-a-swift-package-registry)
* [Tips and Tricks](#tips-and-tricks)
<!-- MARKDOWN TOC: END -->

## Documentation

- [Rules and API documentation](/docs/README.md)
- [Frequently Asked Questions](/docs/faq.md)
- [Migrating from v1 to v2](/docs/v2_migration.md)

## Prerequisites

### Mac OS

Be sure to install Xcode.

### Linux

You will need to [install Swift](https://swift.org/getting-started/#installing-swift). Make sure
that running `swift --version` works properly.

Don't forget that `rules_swift`
[expects the use of `clang`](https://github.com/bazelbuild/rules_swift#3-additional-configuration-linux-only).
Hence, you will need to specify `CC=clang` before running Bazel.

Finally, help [rules_swift] and [rules_swift_package_manager] find the Swift toolchain by ensuring
that a `PATH` that includes the Swift binary is available in the Bazel actions.

```sh
cat >>local.bazelrc <<EOF
build --action_env=PATH
EOF
```

This approach is necessary to successfully execute the examples on an Ubuntu runner using Github
actions. See the [CI GitHub workflow] for more details.

## Quickstart

The following provides a quick introduction on how to set up and use the features in this
repository. Bazel 8 or later and [Bazel modules] are required. The minimum rules_swift version is
4.2.1. See the [rules_swift 4.x migration notes](docs/rules_swift_4_migration.md) for compatibility
changes and opting into explicit modules.

Coming from 1.x? Read the [v1 to v2 migration guide](docs/v2_migration.md).

Also, check out the [examples] for more information.

### 1. Enable bzlmod

This repository supports [bzlmod].

```
common --enable_bzlmod
```

### 2. Configure your `MODULE.bazel` to use [rules_swift_package_manager].

Add a dependency on `rules_swift_package_manager`.

<!-- BEGIN MODULE SNIPPET -->
```python
bazel_dep(name = "rules_swift_package_manager", version = "1.26.0")
```
<!-- END MODULE SNIPPET -->

In addition, add the `swift_deps` extension and the root `use_repo`. The `from_package` tags that
describe your Swift packages are generated for you in step 4 and pulled in with `include()`.

```bazel
swift_deps = use_extension(
    "@rules_swift_package_manager//:extensions.bzl",
    "swift_deps",
)
use_repo(
    swift_deps,
    "swift_package",  # The resolve, update and cache targets.
    # `bazel mod tidy` adds the Swift package repositories here in steps 5 and 7.
    # NOTE: The name of the Bazel external repository for a Swift package is `swiftpkg_xxx` where
    # `xxx` is the Swift package identity, lowercase, with punctuation replaced by `hyphen`. For
    # example, the repository name for apple/swift-nio is `swiftpkg_swift_nio`.
)
```

You will also need to add a dependency on [rules_swift]. The `@swift_package` targets get `swift`
from the rules_swift toolchain through `swift_toolchain_tool` (bazelbuild/rules_swift#2034). Until a
rules_swift release ships it, add the same `git_override` of `rules_swift` that this repository's
`MODULE.bazel` uses.

NOTE: Some Swift package manager features (e.g., resources) use rules from [rules_apple]. It is a
dependency for `rules_swift_package_manager`. However, you do not need to declare it unless you use
any of the rules in your project.

#### (Optional) Configure the `swift package` flags

The `@swift_package` targets apply default flags chosen for Bazel compatibility. To change them, add
a `configure_swift_package` tag:

```starlark
# MODULE.bazel

swift_deps.configure_swift_package(
    cache_path = "spm-cache",
    dependency_caching = False,
    manifest_cache = "none",
    manifest_caching = False,
)
```

Path values must be relative to the workspace root. The flags are part of the cache, so changing
them makes every slice stale until you run `bazel run @swift_package//:cache`.

#### (Optional) Add dependencies to generated Swift package targets

If a generated Swift package target is missing a Bazel dependency, use `configure_package` to append
deps to that generated target.

```bazel
swift_deps.configure_package(
    name = "ExamplePackage",
    target_deps = {
        "ExampleTarget": [
            ":same_build_file_dep",
            "@other_repo//:dep",
            "@//app:main_repo_dep",
        ],
    },
)
```

Keys should usually be Swift package target names without `.rspm`; these map to generated
implementation targets like `ExampleTarget.rspm.__impl`. If a key already contains `.rspm`, it is
matched as a generated target name unchanged.

#### (Optional) Override attributes on generated Bazel targets

When a generated declaration needs an attribute that this ruleset does not model, use the
repeatable, `buildozer`-inspired tags to edit it directly. Each takes a `target` label naming a
declaration in a generated repository and the `attr` to modify.

Nothing is parsed or guessed: you state the type of the value by picking the tag. The `set` verb has
one tag per value type (`bazel_target_set_bool`, `_int`, `_string`, `_string_list`, `_string_dict`),
and so does the `set_select` verb (`bazel_target_set_select_bool_dict`, `_int_dict`, `_string_dict`,
`_string_list_dict`).

```bazel
# Replace (or create) an attribute.
swift_deps.bazel_target_set_bool(
    attr = "alwayslink",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    value = False,
)

swift_deps.bazel_target_set_string_list(
    attr = "copts",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    value = ["-DEXAMPLE_FEATURE"],
)

# Append to a list attribute, after the generated values.
swift_deps.bazel_target_add(
    attr = "copts",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    values = ["-DEXAMPLE_FEATURE"],
)

# Replace an attribute with a `select()`.
swift_deps.bazel_target_set_select_string_list_dict(
    attr = "copts",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    values = {
        "//:release_build": ["-DEXAMPLE_RELEASE_FEATURE"],
        "//conditions:default": [],
    },
)

# Append a `select()` after the generated value.
swift_deps.bazel_target_add_select(
    attr = "copts",
    target = "@swiftpkg_example//:ExampleTarget.rspm.__impl",
    values = {"//:release_build": ["-DEXAMPLE_RELEASE_FEATURE"]},
)
```

Bazel has no `bool` or `int` dictionary attribute, so `bazel_target_set_select_bool_dict` and
`bazel_target_set_select_int_dict` take `string` branch values and convert them. A `bool` branch
must be exactly `True` or `False` and an `int` branch must be digits with an optional leading `-`;
anything else fails when the module extension is evaluated.

Setters accept an empty value, so `value = []` clears a list attribute. `bazel_target_add` requires
at least one value and the `select()` verbs require at least one condition. The `add` verbs are
list-only; use a setter to write a scalar or a `dict`.

Every generated declaration lives in the root package of its repository, so `target` must be of the
form `@repo_name//:target_name`. `select()` keys that are relative to the main repository (e.g.
`//:release_build`) are canonicalized (e.g. `@@//:release_build`) so that they still resolve from
inside the generated repository. `bazel_target_add_select` adds a `//conditions:default` branch when
you do not supply one; the `bazel_target_set_select_*` tags do not.

For a given target and attribute, at most one `bazel_target_set_*` or `bazel_target_set_select_*`
tag may be declared. The setter is applied first, then every `bazel_target_add` in declaration
order, then every `bazel_target_add_select` in declaration order. Because additions land last, flags
that follow last-option-wins semantics (e.g. `copts`) override the generated values.

These tags may only be declared by the root module, and they cannot be combined with a complete
`configure_package(build_file = ...)` override for the same package because that override bypasses
generated declarations. There is no allowlist of attribute names: an attribute that the generated
rule does not understand fails when Bazel loads the generated `BUILD.bazel` file, with Bazel's own
error message. Use at your own risk.

For details on finding the target to modify, the ordering rules, and real-world examples, see [our
document on modifying generated Bazel targets].

### 3. Create a minimal `Package.swift` file.

Create a minimal `Package.swift` file that only contains the external dependencies that are directly
used by your Bazel workspace. This example keeps it in a `swift` directory.

```swift
// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "my-project",
    dependencies: [
        // Replace these entries with your dependencies.
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.4.4"),
    ]
)
```

The name of the package can be whatever you like. It is required for the manifest, but it is not
used by [rules_swift_package_manager]. If your project is published and consumed as a Swift package,
feel free to populate the rest of the manifest so that your package works properly by Swift package
manager. Just note that the [Swift Gazelle plugin] does not use the manifest to generate Bazel build
files.

The manifest is evaluated with `-Xbuild-tools-swiftc -DBAZEL`, so `#if BAZEL` blocks apply when
`rules_swift_package_manager` resolves it ([#2159]).

### 4. Create a slice with `init`.

A _slice_ is one resolution of `Package.swift` for one build configuration. It is a Bazel package in
your tree that holds the slice's `Package.resolved` and the checked-in SwiftPM output. Most clients
need one slice that serves every platform:

```sh
bazel run @rules_swift_package_manager//tools:init -- \
    --swift swift/Package.swift \
    --dir swift_deps/any \
    --config @rules_swift_package_manager//config:any
```

`init` writes `swift_deps/any/BUILD.bazel` and an `inc.MODULE.bazel` with empty manifest lists, and
appends `swift_deps/any/.build` to `.bazelignore` and `.gitignore`. It then prints the `include()`
line to add to `MODULE.bazel`. Add it after the root `use_extension` and `use_repo`, because
`bazel mod tidy` writes `use_repo` into the first file that uses the extension:

```bazel
include("//swift_deps/any:inc.MODULE.bazel")
```

If you already have a `Package.resolved`, pass `--seed path/to/Package.resolved` so SwiftPM keeps
your pins, then delete the original. See [Slices](#slices) for multiple slices.

### 5. Run `bazel mod tidy`.

This makes the root `use_repo` match the new, still empty slice.

### 6. Run `bazel run @swift_package//:resolve`.

```sh
bazel run @swift_package//:resolve
```

This runs `swift package resolve` for the slice, writes `swift_deps/any/Package.resolved`, the cache
under `swift_deps/any/swift_deps_cache/`, and fills the manifest lists in `inc.MODULE.bazel`.

### 7. Run `bazel mod tidy` again.

This adds the Swift package repositories to the root `use_repo`.

### 8. Build and test your project.

Build and test your project.

```sh
bazel test //...
```

### 9. Check in your files.

- `Package.swift`: the dependencies your project uses directly.
- The slice directory (`swift_deps/any/`): `BUILD.bazel`, `inc.MODULE.bazel`, `Package.resolved` and
  `swift_deps_cache/`. The cache is what Bazel reads instead of running `swift`, so it must be
  committed.
- `MODULE.bazel`, `.bazelignore` and `.gitignore`.

Do not commit `swift_deps/any/.build`; it holds SwiftPM checkouts.

### 10. Start coding

You are ready to start coding.

## Updating Swift packages

Bazel never runs `swift` while loading. Everything it needs comes from the checked-in slice, and the
`@swift_package` targets regenerate the slice:

| Command                              | What it does                                                             |
| ------------------------------------ | ------------------------------------------------------------------------ |
| `bazel run @swift_package//:resolve` | `swift package resolve`, then the cache step                             |
| `bazel run @swift_package//:update`  | `swift package update` for every package, then the cache step            |
| `bazel run @swift_package//:cache`   | The cache step only: rewrites `swift_deps_cache/` and `inc.MODULE.bazel` |

Run `resolve` after you change `Package.swift`. Run `cache` after you change a local package's
manifest, a `configure_package` patch or the `configure_swift_package` flags, and after a Swift
minor version upgrade. Run `bazel mod tidy` after any of them adds or removes a package. If you
forget, the build fails with a message that names the slice and the command to run.

The targets act on the slice whose `config` matches the configuration you run them under, so
`bazel run @swift_package//:cache --platforms=<a Linux platform>` acts on a Linux slice. They do not
take extra arguments.

## Slices

A slice directory looks like this:

```
swift_deps/any/
├── BUILD.bazel           # written once by init
├── inc.MODULE.bazel      # the slice's from_package tag; rewritten by the cache step
├── Package.resolved      # this slice's pins
├── swift_deps_cache/     # dump.json and desc.json per package, plus change-detection inputs
└── .build/               # SwiftPM scratch space; listed in .bazelignore and .gitignore
```

Each slice needs a `config`, the label `select()` uses to pick it. The ruleset provides three:

- `@rules_swift_package_manager//config:any` matches every supported OS. Use it when you have one
  slice.
- `@rules_swift_package_manager//config:apple` matches macOS, iOS, tvOS, watchOS and visionOS.
- `@rules_swift_package_manager//config:linux` matches Linux.

Any label that `select()` accepts works. Slice configs must not overlap unless one is strictly
nested in another. `any` overlaps the other two, so use it only when you have one slice.

Two slices are useful when you build on macOS and Linux and the resolution differs between them, for
example because a manifest uses `#if os(Linux)`. Run `init` once per slice with its own `--dir` and
`--config`, and add one `include()` per slice. SwiftPM evaluates manifests for the host it runs on,
so each slice must be regenerated on its own host: run `cache` for a Linux slice on a Linux machine
or in a Linux CI job and commit the result. The `@swift_package` targets refuse to regenerate a
slice for a different host OS. See [examples/pkg_manifest_minimal](examples/pkg_manifest_minimal)
and [examples/multi_slice](examples/multi_slice).

When the slices agree on a package, it gets one repository, as in v1. When they differ, the
package's repository holds aliases that `select()` between hidden per-slice repositories.

### Swift version check

The cache records the Swift version that produced it. A build fails when the resolved Swift
toolchain's `major.minor` version differs, because `Package@swift-*.swift` variants and
`#if swift(...)` depend on it. Rerun `bazel run @swift_package//:cache` on each host and commit. To
skip the check for a while, for example on a newer Xcode than your team, pass
`--@rules_swift_package_manager//:swift_version_check=off`.

## Using a Swift package registry

See [our document on using a Swift package registry](/docs/swift_package_registry.md).

## Tips and Tricks

The following are a few tips to consider as you work with your repository:

- Are you trying to use a Swift package and it just won't build under Bazel? If you can figure out
  how to fix it, you can patch the Swift package. Check out [our document on patching Swift
  packages].

<!-- Links -->

[Bazel modules]: https://bazel.build/external/module
[bzlmod]: https://bazel.build/external/overview#bzlmod
[our document on patching Swift packages]: docs/patch_swift_package.md
[our document on modifying generated Bazel targets]: docs/modify_generated_bazel_targets.md
[CI GitHub workflow]: .github/workflows/ci.yml
[#2159]: https://github.com/cgrindel/rules_swift_package_manager/issues/2159
[Swift Gazelle plugin]: https://github.com/cgrindel/swift_gazelle_plugin
[examples]: examples/
[rules_apple]: https://github.com/bazelbuild/rules_apple
[rules_spm]: https://github.com/cgrindel/rules_spm
[rules_swift]: https://github.com/bazelbuild/rules_swift
[rules_swift_package_manager]: https://github.com/cgrindel/rules_swift_package_manager
[tidy]:
  https://github.com/cgrindel/bazel-starlib/blob/main/doc/bzltidy/rules_and_macros_overview.md#tidy
