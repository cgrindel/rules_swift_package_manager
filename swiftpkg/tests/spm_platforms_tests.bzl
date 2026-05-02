"""Tests for the Swift package platform mapping module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//config_settings/spm/platform:platforms.bzl",
    spm_platforms = "platforms",
)

def _normalize_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, "ios", spm_platforms.normalize("iOS"))
    asserts.equals(env, "macos", spm_platforms.normalize("macOS"))
    asserts.equals(env, "tvos", spm_platforms.normalize("tvOS"))
    asserts.equals(env, "visionos", spm_platforms.normalize("visionOS"))
    asserts.equals(env, "watchos", spm_platforms.normalize("watchOS"))

    return unittest.end(env)

normalize_test = unittest.make(_normalize_test)

def _label_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        "@rules_swift_package_manager//config_settings/spm/platform:visionos",
        spm_platforms.label("visionOS"),
    )

    return unittest.end(env)

label_test = unittest.make(_label_test)

def _supported_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        ["ios", "visionos", "watchos"],
        spm_platforms.supported(["iOS", "visionOS", "watchOS", "macCatalyst"]),
    )

    return unittest.end(env)

supported_test = unittest.make(_supported_test)

def spm_platforms_test_suite():
    return unittest.suite(
        "spm_platforms_tests",
        normalize_test,
        label_test,
        supported_test,
    )
