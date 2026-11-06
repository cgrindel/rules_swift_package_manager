"""Bazel module extensions."""

load("//swiftpkg/bzlmod:swift_deps.bzl", _swift_deps = "swift_deps")
load("//swiftpkg/internal/sdk_inventory:repository.bzl", _sdk_inventory = "sdk_inventory")

swift_deps = _swift_deps
sdk_inventory = _sdk_inventory
