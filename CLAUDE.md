# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this
repository.

## Overview

This is `rules_swift_package_manager` - a Bazel ruleset for downloading, building, and consuming
Swift packages. It builds external Swift packages using rules_swift, rules_apple, and native C/C++
rulesets, making Swift package products and targets available as Bazel targets.

## Common Development Commands

### Building and Testing

- `bazel test //...` - Run all tests in the repository
- `bazel build //...` - Build all targets

### Code Maintenance

- `bazel run //:tidy` - Update source files from build outputs
- `bazel run //:update_build_files` - Update Bazel BUILD files using Gazelle (an alias for
  `//tools/gazelle:update_build_files`)
- `bazel run //:update_files` - Quick update of source files
- `bazel run //:tidy_all` - Run all tidy operations across the repository

### Go-specific Commands

Go is a maintainer-only dev dependency (`tools/generate_ci_workflow`, Gazelle). No Go reaches
clients.

- `bazel run //:go_mod_tidy` - Tidy Go module dependencies
- `bazel run //:go_get_latest` - Update Go dependencies to latest versions

### Example Testing

Examples have individual `do_test` scripts that can be run to test specific functionality.

## Architecture

### Core Components

1. **swiftpkg/** - Main Swift package management logic
   - `defs.bzl` - Public API exports
   - `internal/` - Core implementation including:
     - Swift package repository rules (`swift_package.bzl`, `local_swift_package.bzl`)
     - Build file generation (`build_files.bzl`, `swiftpkg_build_files.bzl`)
     - Package info processing (`pkginfos.bzl`, `pkginfo_*.bzl`)
     - Resource handling (`resource_files.bzl`, `resource_bundle_accessor.bzl`)
   - `bzlmod/` - Bazel module extension for Swift dependencies

2. **tools/** - Client and maintainer tooling
   - `swift_deps_tool/` - Foundation-only Swift binary behind `@swift_package//:resolve`, `:update`
     and `:cache`; runs SwiftPM and writes each slice's `swift_deps_cache/` and `inc.MODULE.bazel`
   - `init/` - Shell script behind `@rules_swift_package_manager//tools:init`; creates a slice
   - `swift` - `swift_toolchain_tool` that gives the tools and the version check the toolchain's
     `swift`
   - `generate_ci_workflow/` - Go program that writes `.github/workflows/ci.yml` (maintainers only)
   - `gazelle/` - Gazelle targets for this repository (maintainers only)

3. **examples/** - Comprehensive test examples for different Swift package scenarios
   - Each example has its own `do_test` script and demonstrates specific features

4. **ci/** - Continuous integration configuration and test definitions

### Key Files

- `extensions.bzl` - Bazel module extensions entry point
- `MODULE.bazel` - Bazel module configuration with runtime dependencies
- `shared.bazelrc` - Common Bazel configuration (bzlmod enabled, Apple toolchain setup)
- `BUILD.bazel` - Root build configuration: `:swift_version_check` flag (loaded by clients, so no
  dev-dependency loads) and maintenance targets

### Testing Strategy

The repository uses extensive integration testing with examples covering real-world Swift package
scenarios like Firebase, gRPC, Stripe, and others. Tests verify both bzlmod and workspace modes.

## Important Notes

- This repository uses bzlmod by default (`--enable_bzlmod` in shared.bazelrc)
- Apple toolchain configuration is handled automatically via apple_support
- The loading phase never runs `swift`. Each slice (`swift_deps/<any|apple|linux>/` in the examples)
  checks in `Package.resolved`, `swift_deps_cache/` and `inc.MODULE.bazel`; regenerate it with
  `bazel run @swift_package//:cache` on a host of the slice's OS. See `docs/v2_migration.md`
- The `tidy` target is crucial for maintaining generated BUILD files and dependencies

## Development Best Practices

- Always use conventional commit format for git commit messages
- The current working directory may be a git worktree. Check by comparing `git rev-parse --git-dir`
  and `git rev-parse --git-common-dir` — if they differ, you are in a linked worktree. Always
  operate relative to the current directory and do not assume paths relative to the main checkout.

### Generating BUILD Files in Starlark

When generating BUILD.bazel file content programmatically (e.g., in repository rules), always use
the modules in `swiftpkg/internal/` rather than string templates:

- `load_statements.new(location, *symbols)` — create load statements
- `build_decls.new(kind, name, attrs)` — create rule declarations
- `build_files.new(load_stmts, decls)` — compose a BUILD file
- `build_files.write(repository_ctx, build_file, path)` — write it to disk

These modules use `starlark_codegen` to handle proper formatting, indentation, and type conversion
(including `Label`, `bool`, `dict`, `list`, etc.). Do not hand-roll string formatting for Starlark
attribute values.
