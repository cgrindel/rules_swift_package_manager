"""Module for Swift package manager platforms."""

# Derived from Platform values
# https://github.com/apple/swift-package-manager/blob/main/Sources/PackageDescription/SupportedPlatforms.swift
spm_platforms = struct(
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
