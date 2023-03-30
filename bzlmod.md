## Quickstart(bzlmod)

The following provides a quick introduction on how to set up and use the features in this
repository. Also, check out the [examples] for more information.

### Enable `bzlmod`

First, you can enable `bzlmod` in `.bazelrc` file.

```
common --enable_bzlmod
```

### 1. Configure your MODULE.bazel to use [swift_bazel].

Update the `MODULE.bazel` file to load the dependencies for [swift_bazel], [rules_swift] and [Gazelle].

```python
bazel_dep(name = "cgrindel_swift_bazel")
git_override(
    module_name = "cgrindel_swift_bazel",
    remote = "https://github.com/cgrindel/swift_bazel",
    # v0.3.3
    commit = "c6c7557724b3b15ae807ca52a06aa247ec69da8c",
)

bazel_dep(name = "cgrindel_bazel_starlib", version = "0.14.9")
bazel_dep(name = "bazel_skylib", version = "1.4.1")
bazel_dep(
    name = "rules_swift",
    version = "1.6.0",
    repo_name = "build_bazel_rules_swift",
)
bazel_dep(
    name = "rules_apple",
    version = "2.1.0",
    repo_name = "build_bazel_rules_apple",
)

bazel_dep(
    name = "bazel_skylib_gazelle_plugin",
    version = "1.4.1",
    dev_dependency = True,
)
bazel_dep(
    name = "gazelle",
    version = "0.29.0",
    dev_dependency = True,
    repo_name = "bazel_gazelle",
)
# swift_deps START
# swift_deps END
```

### 2. Create a minimal `Package.swift` file.

Create a minimal `Package.swift` file that only contains the external dependencies that are directly
used by the Bazel workspace.

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
used by [swift_bazel]. If your proejct is published and consumed as a Swift package, feel free to
populate the rest of the manifest so that your package works properly by Swift package manager. Just
note that the Swift Gazelle plugin does not use the manifest to generate Bazel build files, at this
time.

### 3. Add Gazelle targets to `BUILD.bazel` at the root of your workspace.

Add the following to the `BUILD.bazel` file at the root of your workspace.

```python
load("@bazel_gazelle//:def.bzl", "gazelle", "gazelle_binary")
load("@cgrindel_bazel_starlib//bzltidy:defs.bzl", "tidy")
load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_update_packages")

tidy(
    name = "tidy",
    targets = [
        ":swift_update_pkgs",
        ":update_build_files",
    ],
)

# MARK: - Gazelle

# Ignore the Swift build folder
# gazelle:exclude .build

gazelle_binary(
    name = "gazelle_bin",
    languages = [
        "@bazel_skylib_gazelle_plugin//bzl",
        "@cgrindel_swift_bazel//gazelle",
    ],
)

gazelle(
    name = "update_build_files",
    gazelle = ":gazelle_bin",
)

swift_update_packages(
    name = "swift_update_pkgs",
    gazelle = ":gazelle_bin",
    generate_swift_deps_for_workspace = False,
    update_bzlmod_stanzas = True,
)
```

### 4. Resolve the external dependencies for your project.

Resolve the external dependencies for your project by running the following:

```sh
$ bazel run //:swift_update_pkgs
```

### 5. Create or update Bazel build files for your project.

Generate/update the Bazel build files for your project by running the following:

```sh
$ bazel run //:update_build_files
```

### 6. Build and test your project.

Build and test your project.

```sh
$ bazel test //...
```

### 7. Check in some generated files.

Check in the `Package.resolved`, `swift_deps.bzl`, and the `module_index.json` files that were
generated for you.

- The `Package.resolved` file specifies that exact versions of the dependencies that were
  identified. If you do not keep the `Package.resolved` file, the dependencies written to the
  `swift_deps.bzl` could change when you execute `//:swift_update_pkgs`.
- The `swift_deps.bzl` contains the Bazel repository rule declarations that load your external
  dependencies for the Bazel build.
- The `module_index.json` maps module names to targets that provide a module with that name. This
  file is used by `swift_package` and the Gazelle plugin to resolve dependencies.

You are ready to start coding.

[CI GitHub workflow]: .github/workflows/ci.yml
[Gazelle plugin]: https://github.com/bazelbuild/bazel-gazelle/blob/master/extend.md
[Gazelle]: https://github.com/bazelbuild/bazel-gazelle
[examples]: examples/
[rules_spm]: https://github.com/cgrindel/rules_spm
[rules_swift]: https://github.com/bazelbuild/rules_swift
[swift_bazel]: https://github.com/cgrindel/swift_bazel
[tidy]: https://github.com/cgrindel/bazel-starlib/blob/main/doc/bzltidy/rules_and_macros_overview.md#tidy
