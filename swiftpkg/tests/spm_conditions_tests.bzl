"""Tests for `spm_conditions` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//config_settings/spm/configuration:configurations.bzl",
    spm_configurations = "configurations",
)
load(
    "//config_settings/spm/platform:platforms.bzl",
    spm_platforms = "platforms",
)
load(
    "//config_settings/spm/platform_configuration:platform_configurations.bzl",
    spm_platform_configurations = "platform_configurations",
)
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:spm_conditions.bzl", "spm_conditions")

def _new_test(ctx):
    env = unittest.begin(ctx)

    actual = spm_conditions.new(
        kind = "platform_types",
        condition = "//path/setting:foo",
        value = ["bar"],
    )
    asserts.equals(env, actual.kind, "platform_types")
    asserts.equals(env, actual.condition, "//path/setting:foo")
    asserts.equals(env, actual.value, ["bar"])

    return unittest.end(env)

new_test = unittest.make(_new_test)

def _new_default_test(ctx):
    env = unittest.begin(ctx)

    actual = spm_conditions.new_default(
        kind = "platform_types",
        value = [],
    )
    expected = spm_conditions.new(
        kind = "platform_types",
        condition = "//conditions:default",
        value = [],
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

new_default_test = unittest.make(_new_default_test)

def _new_from_build_setting_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "no condition",
            bs = pkginfos.new_build_setting(
                kind = "linkedLibrary",
                values = ["sqlite3"],
            ),
            exp = [
                spm_conditions.new(value = "sqlite3", kind = "linkedLibrary"),
            ],
        ),
        struct(
            msg = "with a configuration",
            bs = pkginfos.new_build_setting(
                kind = "linkedLibrary",
                values = ["sqlite3"],
                condition = pkginfos.new_build_setting_condition(
                    configuration = spm_configurations.release,
                ),
            ),
            exp = [
                spm_conditions.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                    condition = spm_configurations.label(
                        spm_configurations.release,
                    ),
                ),
            ],
        ),
        struct(
            msg = "with multiple platforms",
            bs = pkginfos.new_build_setting(
                kind = "linkedLibrary",
                values = ["sqlite3"],
                condition = pkginfos.new_build_setting_condition(
                    platforms = [
                        spm_platforms.ios,
                        spm_platforms.tvos,
                    ],
                ),
            ),
            exp = [
                spm_conditions.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                    condition = spm_platforms.label(
                        spm_configurations.ios,
                    ),
                ),
                spm_conditions.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                    condition = spm_platforms.label(
                        spm_configurations.tvos,
                    ),
                ),
            ],
        ),
        struct(
            msg = "with multiple platforms and a configuration",
            bs = pkginfos.new_build_setting(
                kind = "linkedLibrary",
                values = ["sqlite3"],
                condition = pkginfos.new_build_setting_condition(
                    platforms = [
                        spm_platforms.ios,
                        spm_platforms.tvos,
                    ],
                    configuration = spm_configurations.release,
                ),
            ),
            exp = [
                spm_conditions.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                    condition = spm_platform_configurations.label(
                        spm_configurations.ios,
                        spm_configurations.release,
                    ),
                ),
                spm_conditions.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                    condition = spm_platform_configurations.label(
                        spm_configurations.tvos,
                        spm_configurations.release,
                    ),
                ),
            ],
        ),
    ]
    for t in tests:
        actual = spm_conditions.new_from_build_setting(t.bs)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

new_from_build_setting_test = unittest.make(_new_from_build_setting_test)

def spm_conditions_test_suite():
    return unittest.suite(
        "spm_conditions_tests",
        new_test,
        new_default_test,
    )
