"""Module for Bazel's Apple platform types."""

# NOTE: If entries are added/removed from apple_platform_types, be sure
# to update the config_setting and selects.config_setting_group declarations in
# //config_settings/spm_platform/BUILD.bazel.

# List of valid values for Bazel's --apple_platform_type
apple_platform_types = struct(
    macos = "macos",
    ios = "ios",
    tvos = "tvos",
    watchos = "watchos",
    all_values = [
        "macos",
        "ios",
        "tvos",
        "watchos",
    ],
)
