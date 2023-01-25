"""Module for Swift package manager platforms."""

# NOTE: Ensure that the list of spm_platforms below stays in sync with the
# config_setting and selects.config_setting_group declarations in
# //config_settings/spm_platform/BUILD.bazel.

# Derived from Platform values
# https://github.com/apple/swift-package-manager/blob/main/Sources/PackageDescription/SupportedPlatforms.swift
platforms = struct(
    macos = "macos",
    maccatalyst = "maccatalyst",
    ios = "ios",
    tvos = "tvos",
    watchos = "watchos",
    driverkit = "driverkit",
    linux = "linux",
    windows = "windows",
    android = "android",
    wasi = "wasi",
    openbsd = "openbsd",
    all_values = [
        "macos",
        "maccatalyst",
        "ios",
        "tvos",
        "watchos",
        "driverkit",
        "linux",
        "windows",
        "android",
        "wasi",
        "openbsd",
    ],
)
