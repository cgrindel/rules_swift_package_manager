"""Package platform version helpers for minimum OS transition wrappers."""

load(
    "//config_settings/spm/platform:platforms.bzl",
    spm_platforms = "platforms",
)

_MINIMUM_OS_ATTR_BY_PLATFORM = {
    spm_platforms.ios: "ios_minimum_os",
    spm_platforms.macos: "macos_minimum_os",
    spm_platforms.tvos: "tvos_minimum_os",
    spm_platforms.visionos: "visionos_minimum_os",
    spm_platforms.watchos: "watchos_minimum_os",
}

# Repository-time fallbacks for omitted Package.swift platform declarations.
# Match SwiftPM's hard-coded PackageModel.Platform.oldestSupportedVersion
# values, which SwiftPM uses when deriving undeclared package platforms.
# https://github.com/swiftlang/swift-package-manager/blob/1e873736f010e2cb88989d5f23a266d305cf1cbc/Sources/PackageModel/Platform.swift#L40-L46
_FALLBACK_MINIMUM_OS_BY_PLATFORM = {
    spm_platforms.ios: "12.0",
    spm_platforms.macos: "10.13",
    spm_platforms.tvos: "12.0",
    spm_platforms.visionos: "1.0",
    spm_platforms.watchos: "4.0",
}

def _fallback(platform_name):
    platform_name = spm_platforms.normalize(platform_name)
    minimum_os = _FALLBACK_MINIMUM_OS_BY_PLATFORM.get(platform_name)
    if minimum_os == None:
        fail("No fallback minimum OS is defined for platform '{}'.".format(platform_name))
    return minimum_os

def _by_platform(pkg_info):
    versions = {
        platform_name: _fallback(platform_name)
        for platform_name in _MINIMUM_OS_ATTR_BY_PLATFORM
    }

    for platform in pkg_info.platforms:
        platform_name = spm_platforms.normalize(platform.name)
        if platform_name in _MINIMUM_OS_ATTR_BY_PLATFORM:
            versions[platform_name] = platform.version

    return versions

def _transition_attrs(pkg_info):
    versions = _by_platform(pkg_info)
    return {
        attr_name: versions[platform_name]
        for platform_name, attr_name in _MINIMUM_OS_ATTR_BY_PLATFORM.items()
    }

minimum_os_versions = struct(
    by_platform = _by_platform,
    fallback = _fallback,
    transition_attrs = _transition_attrs,
)
