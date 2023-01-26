"""Module for Swift package mananger configuration."""

def _label(name):
    """Returns the condition label for the SPM configuration name.

    Args:
        name: The SPM configuration name as a `string`.

    Returns:
        The condition label as a `string`.
    """
    return "@cgrindel_swift_bazel//config_settings/spm/configuration:{}".format(name)

# Derived from BuildConfiguration values
# https://github.com/apple/swift-package-manager/blob/main/Sources/PackageDescription/BuildSettings.swift
configurations = struct(
    debug = "debug",
    release = "release",
    all_values = [
        "debug",
        "release",
    ],
    label = _label,
)
