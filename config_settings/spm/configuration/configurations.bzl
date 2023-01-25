"""Module for Swift package mananger configuration."""

# Derived from BuildConfiguration values
# https://github.com/apple/swift-package-manager/blob/main/Sources/PackageDescription/BuildSettings.swift
configurations = struct(
    debug = "debug",
    release = "release",
    all_values = [
        "debug",
        "release",
    ],
)
