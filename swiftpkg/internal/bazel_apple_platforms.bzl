"""Module for retrieving information about Apple platforms."""

load("@bazel_skylib//lib:sets.bzl", "sets")
load("//config_settings/spm/platform:platforms.bzl", spm_platforms = "platforms")
load(":apple_builtin_frameworks.bzl", "apple_builtin_frameworks")

# _platforms = struct(
#     macos = "@platforms//os:macos",
#     ios = "@platforms//os:ios",
#     tvos = "@platforms//os:tvos",
#     watchos = "@platforms//os:watchos",
# )

_platform_sets = {
    spm_platforms.macos: apple_builtin_frameworks.macos,
    spm_platforms.ios: apple_builtin_frameworks.ios,
    spm_platforms.tvos: apple_builtin_frameworks.tvos,
    spm_platforms.watchos: apple_builtin_frameworks.watchos,
}

_condition_tmpl = "@cgrindel_swift_bazel//config_settings/spm/platform:{}"

def _for_framework(framework):
    platforms = []
    for (platform, pset) in _platform_sets.items():
        if sets.contains(pset, framework):
            platforms.append(_condition_tmpl.format(platform))
    return sorted(platforms)

bazel_apple_platforms = struct(
    for_framework = _for_framework,
)
