"""Golang dependencies for the `rules_swift_package_manager` repository."""

load("@bazel_gazelle//:deps.bzl", "go_repository")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def swift_bazel_go_dependencies():
    """Declare the Go dependencies for `rules_swift_package_manager`."""
