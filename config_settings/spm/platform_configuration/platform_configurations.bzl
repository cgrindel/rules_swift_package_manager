"""Module for SPM platform-configuration combinations."""

load("//config_settings/spm/configuration:configurations.bzl", "configurations")
load("//config_settings/spm/platform:platforms.bzl", "platforms")

def _new(platform, configuration):
    return struct(
        platform = platform,
        configuration = configuration,
    )

def _new_name(platform, configuration):
    return "{platform}_{configuration}".format(
        configuration = configuration,
        platform = platform,
    )

_ALL_VALUES = [
    _new(platform, configuration)
    for configuration in configurations.all_values
    for platform in platforms.all_values
]

platform_configurations = struct(
    new = _new,
    new_name = _new_name,
    all_values = _ALL_VALUES,
)
