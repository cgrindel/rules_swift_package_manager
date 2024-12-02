"""Defines the public API for `swiftpkg`"""

load("//swiftpkg/internal:local_swift_package.bzl", _local_swift_package = "local_swift_package")
load("//swiftpkg/internal:registry_swift_package.bzl", _registry_swift_package = "registry_swift_package")
load("//swiftpkg/internal:swift_deps_index.bzl", _swift_deps_index = "swift_deps_index")
load("//swiftpkg/internal:swift_deps_info.bzl", _swift_deps_info = "swift_deps_info")
load("//swiftpkg/internal:swift_package.bzl", _swift_package = "swift_package")
load("//swiftpkg/internal:swift_package_tool.bzl", _swift_package_tool = "swift_package_tool")

# Repository rules
swift_package = _swift_package
local_swift_package = _local_swift_package
swift_deps_info = _swift_deps_info
registry_swift_package = _registry_swift_package

# Rules
swift_deps_index = _swift_deps_index
swift_package_tool = _swift_package_tool
