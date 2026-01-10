"""Bazel module extensions."""

load("//swiftpkg/bzlmod:swift_deps.bzl", _swift_deps = "swift_deps")
load("//swiftpkg/bzlmod:swift_dev_deps.bzl", _swift_dev_deps = "swift_dev_deps")

swift_deps = _swift_deps
swift_dev_deps = _swift_dev_deps
