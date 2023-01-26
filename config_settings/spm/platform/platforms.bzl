"""Module for Swift package manager platforms."""

# NOTE: Ensure that the list of spm_platforms below stays in sync with the
# config_setting and selects.config_setting_group declarations in
# //config_settings/spm_platform/BUILD.bazel.

# Derived from Platform values
# https://github.com/apple/swift-package-manager/blob/main/Sources/PackageDescription/SupportedPlatforms.swift
# Not sure how to map the following SPM platforms: maccatalyst, driverkit

_APPLE_PLATFORMS = [
    "macos",
    "ios",
    "tvos",
    "watchos",
]

_NON_APPLE_PLATFORMS = [
    "linux",
    "windows",
    "android",
    "wasi",
    "openbsd",
]

platforms = struct(
    macos = "macos",
    ios = "ios",
    tvos = "tvos",
    watchos = "watchos",
    linux = "linux",
    windows = "windows",
    android = "android",
    wasi = "wasi",
    openbsd = "openbsd",
    apple_platforms = _APPLE_PLATFORMS,
    non_apple_platforms = _NON_APPLE_PLATFORMS,
    all_values = _APPLE_PLATFORMS + _NON_APPLE_PLATFORMS,
)
