"""Shared platform metadata for package minimum OS transition wrappers."""

load(
    "//config_settings/spm/platform:platforms.bzl",
    spm_platforms = "platforms",
)

def _platform_config(platform, attr_name, option, fallback):
    return struct(
        platform = platform,
        attr_name = attr_name,
        option = option,
        fallback = fallback,
    )

# Repository-time fallbacks for omitted Package.swift platform declarations.
# Match SwiftPM's hard-coded PackageModel.Platform.oldestSupportedVersion
# values, which SwiftPM uses when deriving undeclared package platforms.
# https://github.com/swiftlang/swift-package-manager/blob/1e873736f010e2cb88989d5f23a266d305cf1cbc/Sources/PackageModel/Platform.swift#L40-L46
_CONFIGS = [
    _platform_config(
        platform = spm_platforms.ios,
        attr_name = "ios_minimum_os",
        option = "//command_line_option:ios_minimum_os",
        fallback = "12.0",
    ),
    _platform_config(
        platform = spm_platforms.macos,
        attr_name = "macos_minimum_os",
        option = "//command_line_option:macos_minimum_os",
        fallback = "10.13",
    ),
    _platform_config(
        platform = spm_platforms.tvos,
        attr_name = "tvos_minimum_os",
        option = "//command_line_option:tvos_minimum_os",
        fallback = "12.0",
    ),
    _platform_config(
        platform = spm_platforms.visionos,
        attr_name = "visionos_minimum_os",
        # Bazel/apple_support currently expose visionOS through the generic
        # C++ minimum OS flag.
        option = "//command_line_option:minimum_os_version",
        fallback = "1.0",
    ),
    _platform_config(
        platform = spm_platforms.watchos,
        attr_name = "watchos_minimum_os",
        option = "//command_line_option:watchos_minimum_os",
        fallback = "4.0",
    ),
]

def _by_platform():
    return {
        config.platform: config
        for config in _CONFIGS
    }

def _options():
    return sorted([
        config.option
        for config in _CONFIGS
    ])

minimum_os_platforms = struct(
    by_platform = _by_platform,
    options = _options,
)
