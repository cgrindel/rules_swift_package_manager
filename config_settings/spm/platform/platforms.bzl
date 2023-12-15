"""Module for Swift package manager platforms."""

load(
    "//config_settings/bazel/apple_platform_type:apple_platform_types.bzl",
    "apple_platform_types",
)

# NOTE: Ensure that the list of spm_platforms below stays in sync with the
# config_setting and selects.config_setting_group declarations in
# //config_settings/spm/platform/BUILD.bazel.

# Derived from Platform values
# https://github.com/apple/swift-package-manager/blob/main/Sources/PackageDescription/SupportedPlatforms.swift

def _platform_info(spm, bzl, os):
    """Maps the different platform values.

    Args:
        spm: The Swift package manager platform name as a `string`.
        bzl: The Bazel `apple_platform_type` as a `string`.
        os: The Bazel `@platforms//os` name as a `string`.

    Returns:
        A `struct` representing the platform mapping info.
    """
    return struct(
        spm = spm,
        bzl = bzl,
        os = os,
    )

# These values all have corresponding values in
# https://github.com/bazelbuild/platforms/blob/main/os/BUILD
_NON_APPLE_PLATFORMS = [
    "linux",
    "windows",
    "android",
    "wasi",
    "openbsd",
]

_PLATFORM_INFOS = [
    _platform_info(spm = p, bzl = p, os = p)
    for p in apple_platform_types.all_values
] + [
    _platform_info(spm = p, bzl = None, os = p)
    for p in _NON_APPLE_PLATFORMS
] + [
    # Treat `maccatalyst` as an alias of sorts for macos. This will be handled
    # in the `platforms.label` function.
    _platform_info(spm = "maccatalyst", bzl = None, os = None),
    # Map `driverkit` as `macos`. This will be handled in the
    # `platforms.label()` function.
    _platform_info(spm = "driverkit", bzl = None, os = None),
]

def _label(name):
    """Returns the condition label for the SPM platform name.

    Args:
        name: The SPM platform name as a `string`.

    Returns:
        The condition label as a `string`.
    """

    # There is currently no support Mac Catalyst in Bazel. These are Mac apps
    # that use iOS frameworks. Treat it like iOS for now.
    if name == "maccatalyst":
        # name = "ios"
        name = "macos"
    if name == "driverkit":
        name = "macos"
    return "@rules_swift_package_manager//config_settings/spm/platform:{}".format(name)

platforms = struct(
    macos = "macos",
    maccatalyst = "maccatalyst",
    ios = "ios",
    tvos = "tvos",
    watchos = "watchos",
    linux = "linux",
    windows = "windows",
    android = "android",
    wasi = "wasi",
    openbsd = "openbsd",
    all_values = [pi.spm for pi in _PLATFORM_INFOS],
    all_platform_infos = _PLATFORM_INFOS,
    label = _label,
)
