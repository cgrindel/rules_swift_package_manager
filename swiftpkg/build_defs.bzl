"""Defines the public API for `swiftpkg` build rules."""

load(
    "//swiftpkg/internal:generate_modulemap.bzl",
    _generate_modulemap = "generate_modulemap",
)

generate_modulemap = _generate_modulemap
