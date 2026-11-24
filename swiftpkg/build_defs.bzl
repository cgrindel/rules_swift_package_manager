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
load(
    "//swiftpkg/internal:swift_package_stale.bzl",
    _swift_package_stale = "swift_package_stale",
)
load(
    "//swiftpkg/internal:swift_version_check.bzl",
    _swift_version_check = "swift_version_check",
)

generate_modulemap = _generate_modulemap
objc_resource_bundle_accessor_hdr = _objc_resource_bundle_accessor_hdr
objc_resource_bundle_accessor_impl = _objc_resource_bundle_accessor_impl
resource_bundle_accessor = _resource_bundle_accessor
resource_bundle_infoplist = _resource_bundle_infoplist
swift_package_stale = _swift_package_stale
swift_version_check = _swift_version_check
