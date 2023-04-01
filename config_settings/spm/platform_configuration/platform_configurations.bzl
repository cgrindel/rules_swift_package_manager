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

def _label(platform, configuration):
    """Returns the condition label for the SPM platform and configuration.

    Args:
        platform: The SPM platform name as a `string`.
        configuration: The SPM configuration name as a `string`.

    Returns:
        The condition label as a `string`.
    """
    name = _new_name(platform, configuration)
    return """\
@rules_swift_package_manager//config_settings/spm/platform_configuration:{}\
""".format(name)

_ALL_VALUES = [
    _new(platform, configuration)
    for configuration in configurations.all_values
    for platform in platforms.all_values
]

platform_configurations = struct(
    new = _new,
    new_name = _new_name,
    label = _label,
    all_values = _ALL_VALUES,
)
