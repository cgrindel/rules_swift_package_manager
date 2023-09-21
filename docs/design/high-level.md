# Design for Swift Bazel

This document provides a high-level description for the design of the rules and utilities provided
by the Swift Bazel repository.

## Table of Contents

<!-- MARKDOWN TOC: BEGIN -->
* [](#table-of-contents)
* [](#goals)
* [](#implementation)
  * [](#gazelle-plugin)
  * [](#repository-rules-swift_package-and-local_swift_package)
<!-- MARKDOWN TOC: END -->

## Goals

1. Generate Bazel build files for Swift source files in a Bazel workspace.
2. Allow a Bazel workspace to download and use external Swift packages in a Bazel workspace.

## Implementation

The implementation in this repository is separated into two parts:

1. A [Gazelle](https://github.com/bazelbuild/bazel-gazelle) plugin.
2. Bazel repository rules: `swift_package` and `local_swift_package`.

The Gazelle plugin generates Bazel build and Starlark files for your project. The `swift_package`
repository rule generates Bazel build files for the external Swift packages.

### Gazelle Plugin

The [Gazelle](https://github.com/bazelbuild/bazel-gazelle) plugin is [implemented in
Go](https://github.com/bazelbuild/bazel-gazelle/blob/master/extend.md). It has two modes of
operation: `update-repos` and `update`.

The `update-repos` mode 

1. Resolves the direct and transitive dependencies for the project using a `Package.swift` file.
2. Writes a `Package.resolved` file.
3. Writes a `swift_deps_index.json` file.
2. Writes `swift_package` declarations for the direct and transitive dependencies.

The `update` mode

1. Reads the `swift_deps_index.json` file.
2. Inspects the project looking for Swift source files.
3. Identifies the Bazel packages that should contain Swift declarations.
4. Writes the Swift declarations to Bazel build files.

### Repository Rules: `swift_package` and `local_swift_package`

The `swift_package` repository rule downloads a Swift package and generates the Bazel build files
that will build the Swift targets and products.

The `local_swift_package` repository rule references a Swift package directory on disk much like
Bazel's [local_repository](https://bazel.build/reference/be/workspace#local_repository) rule. Like
`swift_package`, it too generates Bazel build files for the Swift package.

The repository rules are implemented using [Bazel Starlark](https://bazel.build/rules/language).

