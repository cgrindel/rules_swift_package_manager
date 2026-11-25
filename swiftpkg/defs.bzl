"""Defines the public API for `swiftpkg`"""

load("//swiftpkg/internal:local_swift_package.bzl", _local_swift_package = "local_swift_package")
load("//swiftpkg/internal:registry_swift_package.bzl", _registry_swift_package = "registry_swift_package")
load("//swiftpkg/internal:swift_package.bzl", _swift_package = "swift_package")
load("//swiftpkg/internal:swift_package_tool_rule.bzl", _swift_package_tool_rule = "swift_package_tool_rule")

# Repository rules
swift_package = _swift_package
local_swift_package = _local_swift_package
registry_swift_package = _registry_swift_package

# Rules
swift_package_tool = _swift_package_tool_rule
