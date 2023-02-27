"""Defines the public API for `swiftpkg` build rules."""

load(
    "//swiftpkg/internal:generate_modulemap.bzl",
    _generate_modulemap = "generate_modulemap",
)
load(
    "//swiftpkg/internal:resource_bundle_accessor.bzl",
    _resource_bundle_accessor = "resource_bundle_accessor",
)

generate_modulemap = _generate_modulemap
resource_bundle_accessor = _resource_bundle_accessor
