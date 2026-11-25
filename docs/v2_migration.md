# Migrating from v1 to v2

In v2, Bazel no longer runs `swift` while it loads your workspace. The `@swift_package` targets run
SwiftPM with the rules_swift toolchain and check its output into your repository, one _slice_ per
build configuration. Bazel only reads those files. See the [README](/README.md#slices) for the slice
layout.

## Table of Contents

<!-- MARKDOWN TOC: BEGIN -->
* [What changed](#what-changed)
* [Migrate step by step](#migrate-step-by-step)
* [Known limitations](#known-limitations)
* [Troubleshooting](#troubleshooting)
  * [Stale slice](#stale-slice)
  * [Missing cache](#missing-cache)
  * [Package missing from a slice](#package-missing-from-a-slice)
  * [No config match](#no-config-match)
  * [Wrong host](#wrong-host)
  * [Swift version mismatch](#swift-version-mismatch)
  * [Leftover `Package.resolved`](#leftover-packageresolved)
  * [Missing `.bazelignore` entry](#missing-bazelignore-entry)
  * [Non-root module](#non-root-module)
  * [Registry package](#registry-package)
<!-- MARKDOWN TOC: END -->

## What changed

- `from_package` needs `config`, `dump_manifests` and `desc_manifests`. A generated
  `inc.MODULE.bazel` per slice holds the tag; you no longer write it by hand. A tag without `config`
  is a v1 tag and fails with a missing mandatory attribute.
- `Package.resolved` moves from beside `Package.swift` into each slice directory.
- `swift_deps_info`, `declare_swift_deps_info`, `swift_deps_index.json` and `cached_json_directory`
  are gone. [swift_gazelle_plugin] users must wait for a plugin release that reads the slice cache.
- `declare_swift_package`, `env`, `env_inherit` and `resolve_transitive_local_dependencies` are gone
  from `from_package`. `@swift_package` is always declared, and local packages are always resolved
  to the end of the graph. Manifests that read the environment are not supported.
- `configure_swift_package.build_path` is gone. The scratch path is always `<slice>/.build`.
- `netrc`, `registries` and `make_files_read_only` are `from_package` attributes, and all root
  slices must agree on `netrc` and `registries`. Add them to the slice's `inc.MODULE.bazel`. The
  tool owns only `desc_manifests` and `dump_manifests`, so `cache`, `resolve` and `update` keep any
  other attribute you add to the tag.
- `inc.MODULE.bazel` belongs to the tool, which rewrites it on every `cache`, `resolve` and
  `update`. It holds exactly one `use_extension` line and one `from_package` tag, with one
  `<name> = <value>,` attribute per line. You may add attributes to the tag, but not comments or
  other tags; the tool fails on them, naming the line. Put comments and other tags, such as
  `configure_package`, in `MODULE.bazel`.
- `patch_cmds` cannot change a manifest. Use `patches` for manifest changes.
- `swift` must come from a rules_swift toolchain: Xcode on macOS, a hermetic or `PATH` toolchain on
  Linux. You need a rules_swift that has `swift_toolchain_tool` (bazelbuild/rules_swift#2034); until
  a release ships it, use the `git_override` from this repository's `MODULE.bazel`.
- Builds fail when the resolved Swift `major.minor` version differs from the one that produced the
  cache. See [Swift version mismatch](#swift-version-mismatch).
- Manifests are still evaluated with `-Xbuild-tools-swiftc -DBAZEL`, so `#if BAZEL` keeps working
  ([#2159]).
- Not supported in v2 yet: Swift package registries ([#2699]) and `from_package` in a non-root
  module ([#2641]).

## Migrate step by step

The steps use one slice, `swift_deps/any`, and a `Package.swift` at the workspace root. Use your own
paths.

1. Delete the v1 `from_package` tag from `MODULE.bazel`; `init` generates its replacement. Its v1
   attributes (`cached_json_directory`, `declare_swift_deps_info`, `declare_swift_package`, `env`,
   `env_inherit`, `resolve_transitive_local_dependencies`) have no v2 equivalent. Also remove
   `build_path` from `configure_swift_package` and `"swift_deps_info"` from `use_repo`.

2. Replace `patch_cmds` that change a package's `Package.swift` with a `patches` file. The cache
   step reads the manifest before the repository rule runs `patch_cmds`, so such a change never
   reaches the cache. See [our document on patching Swift packages](patch_swift_package.md).

3. Create the slice, seeding it from your v1 `Package.resolved`:

   ```sh
   bazel run @rules_swift_package_manager//tools:init -- \
       --swift Package.swift \
       --dir swift_deps/any \
       --config @rules_swift_package_manager//config:any \
       --seed Package.resolved
   ```

   Then delete the v1 `Package.resolved` beside `Package.swift`. The cache step refuses to run while
   it is there.

4. Add the `include()` that `init` printed to `MODULE.bazel`, after the root `use_extension` and
   `use_repo`. `bazel mod tidy` writes `use_repo` into the first file that uses the extension, so
   the order matters.

   ```bazel
   swift_deps = use_extension("@rules_swift_package_manager//:extensions.bzl", "swift_deps")
   use_repo(swift_deps, "swift_package", ...)

   include("//swift_deps/any:inc.MODULE.bazel")
   ```

5. Run `bazel mod tidy`. The v1 `use_repo` lists repositories, such as local packages, that the new
   empty slice does not know yet; tidying first keeps the next step from failing.

6. Run `bazel run @swift_package//:resolve`. It writes the slice's `Package.resolved`, the cache and
   the manifest lists in `inc.MODULE.bazel`.

7. Run `bazel mod tidy` again to put the Swift package repositories back into `use_repo`.

8. Run `bazel test //...`, then commit `MODULE.bazel`, `.bazelignore`, `.gitignore` and the slice
   directory, including `swift_deps_cache/`.

For a second slice, for example a Linux one next to an Apple one, run `init` once per slice with
`@rules_swift_package_manager//config:apple` and `@rules_swift_package_manager//config:linux`, and
add one `include()` per slice. Generate the Linux slice with `bazel run @swift_package//:cache` on a
Linux machine or CI job and commit it.

## Known limitations

- In the alias layout, used when two slices pin a package differently, `bazel_target_*` changes land
  on the hidden `@swiftpkg_<name>__slice_<n>` repositories. A `bazel query` against the top-level
  alias shows none of the attributes; query the target the alias points at instead.
- On the first `cache` after `init`, a `configure_package` tag that matches only by dependency name
  is not applied. Run `cache` a second time.
- `bazel run @swift_package//:update` updates every package; it takes no package arguments.
- Registry packages fail until [#2699] lands. The registry example keeps its v1 setup and is not
  tested until then.
- `from_package` in a non-root module fails ([#2641]).

## Troubleshooting

### Stale slice

```
WARNING: slice `swift_deps/any` (config `@@rules_swift_package_manager+//config:any`) is stale;
run `bazel run @swift_package//:cache` under flags that select that config. Reasons:
_main/Package.swift.cached: missing cached copy; ...
```

The module extension prints this warning, and any target that needs the slice fails with the same
message. An input of the slice changed since its last `cache` run: `Package.swift`, a local
package's manifest, the slice's `Package.resolved`, a patch or the `configure_swift_package` flags.
The reasons say which. Run `cache` under flags that select the slice, on a host of the slice's OS,
then `bazel mod tidy`.

### Missing cache

A slice whose `dump_manifests` or `desc_manifests` names a file that does not exist, such as a new
slice right after `init`, is stale and fails with the message above. Run
`bazel run @swift_package//:resolve` (or `cache`) and commit `swift_deps_cache/`.

### Package missing from a slice

```
package `swift-nio` is not in slice `swift_deps/apple` (config
`@@rules_swift_package_manager+//config:apple`); it is only available to the other slices
```

The package is in another slice but not this one. Add it to `Package.swift` for this platform, or
only depend on it from targets that build for the other slice.

### No config match

```
No slice matches the current configuration; tried: @@rules_swift_package_manager+//config:apple
```

No slice's `config` matches the platform you build or run for. Add a slice for it, or use
`@rules_swift_package_manager//config:any` if you only need one.

### Wrong host

```
target OS 'linux' requires a linux host, but this host is 'macos'
```

SwiftPM evaluates manifests for the host, so a Linux slice can only be regenerated on Linux and an
Apple slice on macOS. Run the command on a host of that OS.

### Swift version mismatch

```
`swift_deps_cache` for slice `swift_deps/any` was produced by Swift 6.3 but this build uses
Swift 6.4; run `bazel run @swift_package//:cache`
```

Rerun `cache` on each host OS and commit. To build anyway for a while, pass
`--@rules_swift_package_manager//:swift_version_check=off`.

### Leftover `Package.resolved`

```
`.../Package.resolved` already exists beside `Package.swift`. If it is a v1 `Package.resolved`,
copy it to `.../swift_deps/any/Package.resolved` (or run `init --seed` for a new slice) and delete
it; then rerun.
```

Do what it says; see step 3.

### Missing `.bazelignore` entry

```
.../.bazelignore must list swift_deps/any/.build; run
`bazel run @rules_swift_package_manager//tools:init` for this slice or add the line
```

Checkouts under `.build` often contain `BUILD.bazel` files, so they must be ignored.

### Non-root module

```
`from_package` slices are only supported in the root module for now (module `<name>`); see
https://github.com/cgrindel/rules_swift_package_manager/issues/2641
```

A dependency module declares `from_package`. This is not supported in v2 yet.

### Registry package

```
registry package `<identity>` is not supported by slices yet; see
https://github.com/cgrindel/rules_swift_package_manager/issues/2699
```

Swift package registries are not supported in v2 until #2699 lands.

[#2159]: https://github.com/cgrindel/rules_swift_package_manager/issues/2159
[#2641]: https://github.com/cgrindel/rules_swift_package_manager/issues/2641
[#2699]: https://github.com/cgrindel/rules_swift_package_manager/issues/2699
[swift_gazelle_plugin]: https://github.com/cgrindel/swift_gazelle_plugin
