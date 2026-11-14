"""Bazel module extensions."""

load("//swiftpkg/bzlmod:sdk_inventory.bzl", _sdk_inventory = "sdk_inventory")
load("//swiftpkg/bzlmod:swift_deps.bzl", _swift_deps = "swift_deps")

swift_deps = _swift_deps
sdk_inventory = _sdk_inventory
