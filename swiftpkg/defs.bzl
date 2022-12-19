"""Defines the public API for `swiftpkg`"""

load("//swiftpkg/internal:local_swift_package.bzl", _local_swift_package = "local_swift_package")
load("//swiftpkg/internal:swift_package.bzl", _swift_package = "swift_package")

swift_package = _swift_package
local_swift_package = _local_swift_package
