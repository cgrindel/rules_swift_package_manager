# Legacy Quickstart

If you are using Bazel's legacy external dependency mechanism (i.e., listing your external
dependencies in the `WORKSPACE` file), this document describes how to get started. Otherwise, please
use [the quickstart instructions in the `README.md`](/README.md#quickstart).

## Table of Contents

<!-- MARKDOWN TOC: BEGIN -->
* [Add declarations to your `WORKSPACE` file](#add-declarations-to-your-workspace-file)
* [Create a minimal `Package.swift` file.](#create-a-minimal-packageswift-file)
* [Add Gazelle targets to `BUILD.bazel` at the root of your workspace.](#add-gazelle-targets-to-buildbazel-at-the-root-of-your-workspace)
* [Resolve the external dependencies for your project.](#resolve-the-external-dependencies-for-your-project)
* [Create or update Bazel build files for your project.](#create-or-update-bazel-build-files-for-your-project)
* [Build and test your project.](#build-and-test-your-project)
* [Check-in `Package.resolved`, `swift_deps_index.json`, and `swift_deps.bzl`.](#check-in-packageresolved-swift_deps_indexjson-and-swift_depsbzl)
<!-- MARKDOWN TOC: END -->

## Add declarations to your `WORKSPACE` file

Update the `WORKSPACE` file to load the dependencies for [rules_swift_package_manager],
[rules_swift] and [Gazelle]. The snippet that you need can be found on [the release
page].

The `WORKSPACE` boilerplate loads a file called `swift_deps.bzl`. The Gazelle plugin will
populate it, shortly. For now, create the file with the follwing contents:

```python
# Contents of swift_deps.bzl
def swift_dependencies():
    pass
```

## Create a minimal `Package.swift` file.

Create a minimal `Package.swift` file that only contains the external dependencies that are directly
used by your Bazel workspace.

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
used by [rules_swift_package_manager]. If your proejct is published and consumed as a Swift package,
feel free to populate the rest of the manifest so that your package works properly by Swift package
manager. Just note that the Swift Gazelle plugin does not use the manifest to generate Bazel build
files, at this time.

## Add Gazelle targets to `BUILD.bazel` at the root of your workspace.

Add the following to the `BUILD.bazel` file at the root of your workspace.

```python
load("@bazel_gazelle//:def.bzl", "gazelle", "gazelle_binary")
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_update_packages")

# Ignore the `.build` folder that is created by running Swift package manager
# commands. The Swift Gazelle plugin executes some Swift package manager
# commands to resolve external dependencies. This results in a `.build` file
# being created.
# NOTE: Swift package manager is not used to build any of the external packages.
# The `.build` directory should be ignored. Be sure to configure your source
# control to ignore it (i.e., add it to your `.gitignore`).
# gazelle:exclude .build

# This declaration builds a Gazelle binary that incorporates all of the Gazelle
# plugins for the languages that you use in your workspace. In this example, we
# are only listing the Gazelle plugin for Swift from rules_swift_package_manager.
gazelle_binary(
    name = "gazelle_bin",
    languages = [
        "@rules_swift_package_manager//gazelle",
    ],
)

# This target updates the Bazel build files for your project. Run this target
# whenever you add or remove source files from your project.
gazelle(
    name = "update_build_files",
    data = [
        "@swift_deps_info//:swift_deps_index",
    ],
    extra_args = [
        "-swift_dependency_index=$(location @swift_deps_info//:swift_deps_index)",
    ],
    gazelle = ":gazelle_bin",
)
```

## Resolve the external dependencies for your project.

Resolve the external dependencies for your project by running the following:

```sh
$ bazel run //:swift_update_pkgs
```

## Create or update Bazel build files for your project.

Generate/update the Bazel build files for your project by running the following:

```sh
$ bazel run //:update_build_files
```

## Build and test your project.

Build and test your project.

```sh
$ bazel test //...
```

## Check-in `Package.resolved`, `swift_deps_index.json`, and `swift_deps.bzl`.

- The `Package.resolved` file specifies that exact versions of the dependencies that were
  identified.
- The `swift_deps_index.json` file contains information that is used by the Gazelle plugin and the
  respository rules.
- The `swift_deps.bzl` file contains the repository rule declarations that are required to download
  and prepare the external Swift packages that are used by your workspace.

<!-- Links -->

[rules_swift_package_manager]: https://github.com/cgrindel/rules_swift_package_manager
[Gazelle]: https://github.com/bazelbuild/bazel-gazelle
[rules_swift]: https://github.com/bazelbuild/rules_swift
[the release page]: https://github.com/cgrindel/rules_swift_package_manager/releases
