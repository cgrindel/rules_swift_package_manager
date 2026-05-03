# Caching Swift Package Manifests

When `rules_swift_package_manager` resolves a Swift package, it shells
out to SPM (`swift package dump-package` and `swift package describe`)
to discover the package's products, targets, and dependencies. Those
SPM commands run via `xcrun` against whatever Swift toolchain
`xcode-select` points at, while Bazel compiles your code against the
toolchain it resolves through `--xcode_version_config` /
`rules_swift`. When those two toolchains disagree, SPM evaluates `#if
compiler(>=X.Y)` blocks against one Swift version while Bazel compiles
the resulting code with another, which can break the build.

The cache feature lets you commit the output of those SPM commands —
generated through the active Bazel Swift toolchain — into your
workspace. At fetch time the rules read the cached JSON instead of
shelling out, so SPM inspection and Bazel compilation always agree.

This guide walks through setting up the cache, refreshing it, and the
`swift_info_test` build-time check that catches drift.

## When you want this

- `#if compiler(>=X.Y)` evaluates differently under Apple Swift vs.
  open-source Swift, or under different Xcode versions, and that has
  caused build breakages.
- Your team uses a Swift toolchain that differs from the macOS default
  (e.g. a pinned `rules_swift` toolchain on Linux CI).
- You want repository fetches to be faster and not require a working
  `xcrun` on every developer machine.

If none of these apply, you can keep the existing default behavior and
skip this guide.

## 1. Add `platforms` as a direct `bazel_dep`

The cache utility auto-emits a `swift_info_test` target with
`target_compatible_with = ["@platforms//os:<host_os>"]`. For that label
to resolve under bzlmod visibility rules, your `MODULE.bazel` needs
`platforms` as a direct dep:

```python
bazel_dep(name = "platforms", version = "1.0.0")
```

## 2. Generate the cache

Run the cache utility from the directory containing the `Package.swift`
you've configured `swift_deps.from_package` against:

```sh
$ bazel run @swift_package//:cache -- \
    --mode update \
    --output_dir swift_deps_cache
```

`--output_dir` is workspace-relative. Pick any directory; the example
uses `swift_deps_cache` at the workspace root.

The utility:

- Runs `swift package resolve` (or `update`) through the active Bazel
  Swift worker so the cache reflects the same toolchain Bazel will use
  to compile.
- Calls `swift package dump-package` and `swift package describe
--type json` for the root package and every transitive dependency
  (local `fileSystem` deps, SCM checkouts, registry packages).
- Writes one subdirectory per dependency, each with a `desc.json`, a
  `dump.json`, and a tiny `BUILD.bazel` that exports them.
- Writes a top-level `swift_info.json` recording the Swift toolchain
  version the cache was generated against, plus a root `BUILD.bazel`
  that declares `swift_info_test`.
- Updates your `MODULE.bazel` via buildozer: `dump_manifests` and
  `desc_manifests` dicts on the `swift_deps.from_package` tag get
  populated with `<identity>: //<output_dir>/<identity>:<file>.json`
  entries.

Commit the resulting `swift_deps_cache/` tree and the `MODULE.bazel`
edits.

The committed cache stores workspace-internal sibling-package paths as
a `{{WORKSPACE_ROOT}}/<rel>` token so the same cache works for every
checkout. The token is expanded against `repository_ctx.workspace_root`
at fetch time.

## 3. The `swift_info_test` check

The cache utility emits a `swift_info_test` target into the cache
directory's `BUILD.bazel`. When `bazel test //...` runs it, the test
compares the Swift version recorded in `swift_info.json` (when the
cache was generated) against the version Bazel resolves now. If they
disagree the test fails with:

```
ERROR: Swift toolchain mismatch with cached swift_info.json:
  cached:  Apple Swift version 6.2.3 ...
  current: Swift version 6.1 ...

Run 'bazel run @swift_package//:cache -- --mode=update' to refresh.
```

A single committed cache can only match one (OS, toolchain)
combination, so the auto-emitted test is pinned with
`target_compatible_with` to the host OS that produced the cache (e.g.
`@platforms//os:macos`). Cross-platform CI auto-skips it on other
platforms instead of failing.

If a teammate switches Xcode versions or you bump `rules_swift`, this
test catches the drift on the next `bazel test //...`.

## 4. Refreshing the cache

Re-run the same command:

```sh
$ bazel run @swift_package//:cache -- \
    --mode update \
    --output_dir swift_deps_cache
```

`--mode update` regenerates everything. Stale per-dep directories that
no longer correspond to a discovered dependency are pruned.

You can also use `--mode resolve` to validate the cache against the
current toolchain without regenerating:

```sh
$ bazel run @swift_package//:cache -- \
    --mode resolve \
    --output_dir swift_deps_cache
```

This fails fast if the toolchain has drifted. If `swift_info.json`
doesn't exist yet, `--mode resolve` silently switches to update mode so
first-time setup works without two commands.

## Per-package attributes

The bzlmod extension wires the cache to each repo rule via the
`cached_dump_manifest` and `cached_desc_manifest` label attrs on
`swift_package`, `local_swift_package`, and `registry_swift_package`.
You normally don't set these directly — the `dump_manifests` /
`desc_manifests` dicts on the `swift_deps.from_package` tag distribute
them. The per-rule attrs are useful if you wire packages by hand
without going through `from_package`.

## Migrating from `cached_json_directory`

The older `cached_json_directory` attribute (on the bzlmod tag and on
the three repo rules) is deprecated. Setting both `cached_json_directory`
and `dump_manifests` / `desc_manifests` (or the per-rule `cached_*_manifest`
pair) is a hard error.

To migrate:

1. Delete your existing `cached_json_directory` and the directory it
   pointed at.
2. Run the cache utility as described above.
3. Verify `MODULE.bazel` was updated with `dump_manifests` /
   `desc_manifests` entries.

## Example

See [`examples/pkg_manifest_minimal`][example] for a working setup,
including `MODULE.bazel` wiring, a populated `swift_deps_cache/`
directory, and the auto-emitted `swift_info_test`.

[example]: /examples/pkg_manifest_minimal
