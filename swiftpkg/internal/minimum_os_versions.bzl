"""Package platform version helpers for minimum OS transition wrappers."""

load(
    "//config_settings/spm/platform:platforms.bzl",
    spm_platforms = "platforms",
)
load(":minimum_os_platforms.bzl", "minimum_os_platforms")

_MINIMUM_OS_CONFIG_BY_PLATFORM = minimum_os_platforms.by_platform()

def _fallback(platform_name):
    platform_name = spm_platforms.normalize(platform_name)
    config = _MINIMUM_OS_CONFIG_BY_PLATFORM.get(platform_name)
    if config == None:
        fail("No fallback minimum OS is defined for platform '{}'.".format(platform_name))
    return config.fallback

def _by_platform(pkg_info):
    versions = {
        platform_name: config.fallback
        for platform_name, config in _MINIMUM_OS_CONFIG_BY_PLATFORM.items()
    }

    for platform in pkg_info.platforms:
        if platform.name in _MINIMUM_OS_CONFIG_BY_PLATFORM:
            versions[platform.name] = platform.version

    return versions

def _transition_attrs(pkg_info):
    versions = _by_platform(pkg_info)
    return {
        config.attr_name: versions[platform_name]
        for platform_name, config in _MINIMUM_OS_CONFIG_BY_PLATFORM.items()
    }

minimum_os_versions = struct(
    by_platform = _by_platform,
    fallback = _fallback,
    transition_attrs = _transition_attrs,
)
