"""Defines the public API for `swiftpkg` build rules."""

load(
    "//swiftpkg/internal:generate_modulemap.bzl",
    _generate_modulemap = "generate_modulemap",
)
load(
    "//swiftpkg/internal:objc_resource_bundle_accessor.bzl",
    _objc_resource_bundle_accessor_hdr = "objc_resource_bundle_accessor_hdr",
    _objc_resource_bundle_accessor_impl = "objc_resource_bundle_accessor_impl",
)
load(
    "//swiftpkg/internal:resource_bundle_accessor.bzl",
    _resource_bundle_accessor = "resource_bundle_accessor",
)
load(
    "//swiftpkg/internal:resource_bundle_infoplist.bzl",
    _resource_bundle_infoplist = "resource_bundle_infoplist",
)

generate_modulemap = _generate_modulemap
objc_resource_bundle_accessor_hdr = _objc_resource_bundle_accessor_hdr
objc_resource_bundle_accessor_impl = _objc_resource_bundle_accessor_impl
resource_bundle_accessor = _resource_bundle_accessor
resource_bundle_infoplist = _resource_bundle_infoplist
