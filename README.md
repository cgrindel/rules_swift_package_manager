# Gazelle Plugin for Swift and Swit Package Rules for Bazel

This repository contains a [Gazelle plugin] and Bazel repository rules that can be used to download,
build, and consume Swift packages with [rules_swift] rules. The rules in this repository build the
external Swift packages using [rules_swift] and native C/C++ rulesets making the Swift package
products and targets available as Bazel targets.

This repository is designed to fully replace [rules_spm] and provide utilities to ease Swift
development inside a Bazel workspace.

## Table of Contents

<!-- MARKDOWN TOC: BEGIN -->
* [Documentation](#documentation)
* [Prerequisites](#prerequisites)
  * [Mac OS](#mac-os)
  * [Linux](#linux)
* [Quickstart](#quickstart)
  * [1\. Configure your workspace to use swift\_bazel \.](https://github.com/cgrindel/swift_bazel)
  * [2\. Create a minimal Package\.swift file\.](#2-create-a-minimal-packageswift-file)
  * [3\. Add Gazelle targets to BUILD\.bazel at the root of your workspace\.](#3-add-gazelle-targets-to-buildbazel-at-the-root-of-your-workspace)
  * [4\. Resolve the external dependencies for your project\.](#4-resolve-the-external-dependencies-for-your-project)
  * [5\. Create or update Bazel build files for your project\.](#5-create-or-update-bazel-build-files-for-your-project)
  * [6\. Build and test your project\.](#6-build-and-test-your-project)
  * [7\. Check in some generated files\.](#7-check-in-some-generated-files)
* [Tips and Tricks](#tips-and-tricks)
* [Future Work](#future-work)
<!-- MARKDOWN TOC: END -->

## Documentation

- [High-level design](docs/design/high-level.md)
- [Frequently Asked Questions](docs/faq.md)


## Prerequisites

### Mac OS

Be sure to install Xcode.

### Linux

You will need to [install Swift](https://swift.org/getting-started/#installing-swift). Make sure
that running `swift --version` works properly.

Don't forget that `rules_swift` [expects the use of
`clang`](https://github.com/bazelbuild/rules_swift#3-additional-configuration-linux-only). Hence,
you will need to specify `CC=clang` before running Bazel.

Finally, help [rules_swift] and [swift_bazel] find the Swift toolchain by ensuring that a `PATH`
that includes the Swift binary is available in the Bazel actions.

```sh
cat >>local.bazelrc <<EOF
build --action_env=PATH
EOF
```

This approach is necessary to successfully execute the examples on an Ubuntu runner using Github
actions. See the [CI GitHub workflow] for more details.


## Quickstart

The following provides a quick introduction on how to set up and use the features in this
repository. Also, check out the [examples] for more information.

### 1. Configure your workspace to use [swift_bazel].

Update the `WORKSPACE` file to load the dependencies for [swift_bazel], [rules_swift] and [Gazelle].

```python
workspace(name = "my_project")

# MARK: - swift_bazel

http_archive(
    name = "cgrindel_swift_bazel",
    # See the README or release for the full declaration
)

load("@cgrindel_swift_bazel//:deps.bzl", "swift_bazel_dependencies")

swift_bazel_dependencies()

load("@cgrindel_bazel_starlib//:deps.bzl", "bazel_starlib_dependencies")

bazel_starlib_dependencies()

# MARK: - bazel-gazelle

# gazelle:repo bazel_gazelle

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")
load("@cgrindel_swift_bazel//:go_deps.bzl", "swift_bazel_go_dependencies")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

# Declare Go dependencies before calling go_rules_dependencies.
swift_bazel_go_dependencies()

go_rules_dependencies()

go_register_toolchains(version = "1.19.1")

gazelle_dependencies()

# MARK: - rules_swift

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "build_bazel_rules_swift",
    sha256 = "32f95dbe6a88eb298aaa790f05065434f32a662c65ec0a6aabdaf6881e4f169f",
    url = "https://github.com/bazelbuild/rules_swift/releases/download/1.5.0/rules_swift.1.5.0.tar.gz",

)

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)
load("//:swift_deps.bzl", "swift_dependencies")

# gazelle:repository_macro swift_deps.bzl%swift_dependencies
swift_dependencies()

swift_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:extras.bzl",
    "swift_rules_extra_dependencies",
)

swift_rules_extra_dependencies()
```

The above `WORKSPACE` boilerplate loads a file called `swift_deps.bzl`. The Gazelle plugin will
populate it, shortly. For now, create the file with the follwing contents:

```python
# Contents of swift_deps.bzl
def swift_dependencies():
    pass
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

# Ignore the `.build` folder that is created by running Swift package manager 
# commands. The Swift Gazelle plugin executes some Swift package manager commands to resolve
# external dependencies. This results in a `.build` file being created.
# NOTE: Swift package manager is not used to build any of the external packages. The `.build`
# directory should be ignored. Be sure to configure your source control to ignore it (i.e., add it
# to your `.gitignore`).
# gazelle:exclude .build

# This declaration builds a Gazelle binary that incorporates all of the Gazelle plugins for the
# languages that you use in your workspace. In this example, we are using the Gazelle plugin for
# Starlark from bazel_skylib and the Gazelle plugin for Swift from cgrindel_swift_bazel.
gazelle_binary(
    name = "gazelle_bin",
    languages = [
        "@bazel_skylib//gazelle/bzl",
        "@cgrindel_swift_bazel//gazelle",
    ],
)

# This target should be run whenever the list of external dependencies is updated in the
# `Package.swift`. Running this target will populate the `swift_deps.bzl` with `swift_package`
# declarations for all of the direct and transitive Swift packages that your project uses.
gazelle(
    name = "swift_update_repos",
    args = [
        "-from_file=Package.swift",
        "-to_macro=swift_deps.bzl%swift_dependencies",
        "-prune",
    ],
    command = "update-repos",
    gazelle = ":gazelle_bin",
)

# This target updates the Bazel build files for your project. Run this target whenever you add or
# remove source files from your project.
gazelle(
    name = "update_build_files",
    gazelle = ":gazelle_bin",
)
```

### 4. Resolve the external dependencies for your project.

Resolve the external dependencies for your project by running the following:

```sh
$ bazel run //:swift_update_repos
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
  `swift_deps.bzl` could change when you execute `//:swift_update_repos`.
- The `swift_deps.bzl` contains the Bazel repository rule declarations that load your external
  dependencies for the Bazel build.
- The `module_index.json` maps module names to targets that provide a module with that name. This
  file is used by `swift_package` and the Gazelle plugin to resolve dependencies.

You are ready to start coding.

## Tips and Tricks

The following are a few tips to consider as you work with your repository:

- When you add or remove source files, run `bazel run //:update_build_files`. This will
  create/update the Bazel build files in your project. It is designed to be fast and unobtrusive.
- When you add or remove an external dependency, run `bazel run //:swift_update_repos`. This
  will resolve the changes to your transitive dependencies and regenerate your `Package.resolved`
  and `module_index.json`.
- If things do not appear to be working properly, run the following in this order:
  - `bazel run //:swift_update_repos`
  - `bazel run //:update_build_files`
- Do yourself a favor and create a Bazel target (e.g., `//:tidy`) that runs your repository
  maintenance targets (e.g., `//:swift_update_repos`, `//:update_build_files`, formatting utilities) 
  in the proper order.  If you are looking for an easy way to set this up, check out the 
  [`//:tidy` declaration in this repository](BUILD.bazel) and the documentation for the [tidy] macro. 


## Future Work

- [ ] Update the Gazelle plugin to generate Bazel build files from a project's Swift package
  manifest (e.g. `Package.swift`). NOTE: The `swift_package` repository rule does generate Bazel build
  files from a package's project manifest.
- [ ] Update the Gazelle plugin to support common Swift project layouts. The Gazelle plugin knows
  how to interpret projects with `Sources` and `Tests` directories. We are looking for feedback
  about other common patterns to make the Gazelle plugin more robust.


[CI GitHub workflow]: .github/workflows/ci.yml
[Gazelle plugin]: https://github.com/bazelbuild/bazel-gazelle/blob/master/extend.md
[Gazelle]: https://github.com/bazelbuild/bazel-gazelle
[examples]: examples/
[rules_spm]: https://github.com/cgrindel/rules_spm
[rules_swift]: https://github.com/bazelbuild/rules_swift
[swift_bazel]: https://github.com/cgrindel/swift_bazel
[tidy]: https://github.com/cgrindel/bazel-starlib/blob/main/doc/bzltidy/rules_and_macros_overview.md#tidy
