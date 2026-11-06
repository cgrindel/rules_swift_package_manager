"""Unmodified blocks from rules_swift 4.2.2 generated BUILD files (Xcode 27.0).

Verified unchanged against rules_swift 4.2.1 on the same Xcode.
Captured from @system_sdk and @system_sdk_xcode_27_0_0_27A266a. Only the
Foundation, UIKit, Dispatch, Foundation_clang and all_modules aliases and
config_settings are retained. Keep formatting intact: it is the adapter contract.
"""

HUB_BUILD = """config_setting(
    name = "xcode_27_0_0_27A266a",
    flag_values = {
        "@bazel_tools//tools/osx:xcode_version_flag_exact": "27.0.0.27A266a",
    },
)

alias(
    name = "Dispatch",
    actual = select({
        ":xcode_27_0_0_27A266a": "@system_sdk_xcode_27_0_0_27A266a//:Dispatch",
    }),
)

alias(
    name = "Foundation",
    actual = select({
        ":xcode_27_0_0_27A266a": "@system_sdk_xcode_27_0_0_27A266a//:Foundation",
    }),
)

alias(
    name = "Foundation_clang",
    actual = select({
        ":xcode_27_0_0_27A266a": "@system_sdk_xcode_27_0_0_27A266a//:Foundation_clang",
    }),
)

alias(
    name = "UIKit",
    actual = select({
        ":xcode_27_0_0_27A266a": "@system_sdk_xcode_27_0_0_27A266a//:UIKit",
    }),
)

alias(
    name = "all_modules",
    actual = select({
        ":xcode_27_0_0_27A266a": "@system_sdk_xcode_27_0_0_27A266a//:all_modules",
    }),
)
"""

XCODE_BUILD = """config_setting(
    name = "MacOSX_sdk",
    constraint_values = [
        "@platforms//os:macos",
    ],
    visibility = ["//visibility:private"],
)

config_setting(
    name = "iPhoneOS_sdk",
    constraint_values = [
        "@platforms//os:ios",
        "@apple_support//constraints:device",
    ],
    visibility = ["//visibility:private"],
)

config_setting(
    name = "iPhoneSimulator_sdk",
    constraint_values = [
        "@platforms//os:ios",
        "@apple_support//constraints:simulator",
    ],
    visibility = ["//visibility:private"],
)

alias(
    name = "Dispatch",
    actual = select({
        ":MacOSX_sdk": ":MacOSX_Dispatch",
        ":iPhoneOS_sdk": ":iPhoneOS_Dispatch",
        ":iPhoneSimulator_sdk": ":iPhoneSimulator_Dispatch",
    }),
)

alias(
    name = "Foundation",
    actual = select({
        ":MacOSX_sdk": ":MacOSX_Foundation",
        ":iPhoneOS_sdk": ":iPhoneOS_Foundation",
        ":iPhoneSimulator_sdk": ":iPhoneSimulator_Foundation",
    }),
)

alias(
    name = "Foundation_clang",
    actual = select({
        ":MacOSX_sdk": ":MacOSX_Foundation_clang",
        ":iPhoneOS_sdk": ":iPhoneOS_Foundation_clang",
        ":iPhoneSimulator_sdk": ":iPhoneSimulator_Foundation_clang",
    }),
)

alias(
    name = "UIKit",
    actual = select({
        ":iPhoneOS_sdk": ":iPhoneOS_UIKit",
        ":iPhoneSimulator_sdk": ":iPhoneSimulator_UIKit",
    }),
)

alias(
    name = "all_modules",
    actual = select({
        ":MacOSX_sdk": ":MacOSX_all_modules",
        ":iPhoneOS_sdk": ":iPhoneOS_all_modules",
        ":iPhoneSimulator_sdk": ":iPhoneSimulator_all_modules",
        "@platforms//os:none": ":_empty_all_modules",
    }),
)
"""
