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
- `bazel run //:update_build_files` - Update Bazel BUILD files using Gazelle
- `bazel run //:update_files` - Quick update of source files
- `bazel run //:tidy_all` - Run all tidy operations across the repository

### Go-specific Commands

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

2. **tools/swift_deps_index/** - Go-based tooling for Swift dependency analysis

   - Processes Swift package manifests and resolution data
   - Generates dependency indexes and metadata

3. **examples/** - Comprehensive test examples for different Swift package scenarios

   - Each example has its own `do_test` script and demonstrates specific features

4. **ci/** - Continuous integration configuration and test definitions

### Key Files

- `extensions.bzl` - Bazel module extensions entry point
- `MODULE.bazel` - Bazel module configuration with runtime dependencies
- `shared.bazelrc` - Common Bazel configuration (bzlmod enabled, Apple toolchain setup)
- `BUILD.bazel` - Root build configuration with Gazelle and maintenance targets

### Testing Strategy

The repository uses extensive integration testing with examples covering real-world Swift package
scenarios like Firebase, gRPC, Stripe, and others. Tests verify both bzlmod and workspace modes.

## Important Notes

- This repository uses bzlmod by default (`--enable_bzlmod` in shared.bazelrc)
- Apple toolchain configuration is handled automatically via apple_support
- Swift package resolution requires `Package.swift` and `Package.resolved` files
- The `tidy` target is crucial for maintaining generated BUILD files and dependencies

## Development Best Practices

- Always use conventional commit format for git commit messages