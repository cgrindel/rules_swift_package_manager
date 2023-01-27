"""Tests for `bzl_selects` module."""

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
load("//swiftpkg/internal:bzl_selects.bzl", "bzl_selects")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:starlark_codegen.bzl", scg = "starlark_codegen")

def _new_test(ctx):
    env = unittest.begin(ctx)

    actual = bzl_selects.new(
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

    actual = bzl_selects.new_default(
        kind = "platform_types",
        value = [],
    )
    expected = bzl_selects.new(
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
                bzl_selects.new(value = "sqlite3", kind = "linkedLibrary"),
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
                bzl_selects.new(
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
                bzl_selects.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                    condition = spm_platforms.label(
                        spm_platforms.ios,
                    ),
                ),
                bzl_selects.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                    condition = spm_platforms.label(
                        spm_platforms.tvos,
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
                bzl_selects.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                    condition = spm_platform_configurations.label(
                        spm_platforms.ios,
                        spm_configurations.release,
                    ),
                ),
                bzl_selects.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                    condition = spm_platform_configurations.label(
                        spm_platforms.tvos,
                        spm_configurations.release,
                    ),
                ),
            ],
        ),
    ]
    for t in tests:
        actual = bzl_selects.new_from_build_setting(t.bs)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

new_from_build_setting_test = unittest.make(_new_from_build_setting_test)

def _to_starlark_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "string values",
            khs = {},
            vals = ["first", "second"],
            exp = """\
[
    "first",
    "second",
]\
""",
        ),
        struct(
            msg = "no condition values",
            khs = {},
            vals = [
                bzl_selects.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                ),
                bzl_selects.new(
                    value = "z",
                    kind = "linkedLibrary",
                ),
            ],
            exp = """\
[
    "sqlite3",
    "z",
]\
""",
        ),
        struct(
            msg = "with transform",
            khs = {
                "linkedLibrary": bzl_selects.new_kind_handler(
                    transform = lambda v: "-l{}".format(v),
                ),
            },
            vals = [
                bzl_selects.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                ),
                bzl_selects.new(
                    value = "z",
                    kind = "linkedLibrary",
                ),
            ],
            exp = """\
[
    "-lsqlite3",
    "-lz",
]\
""",
        ),
        struct(
            msg = "one with condition, one without condition, no default",
            khs = {},
            vals = [
                bzl_selects.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                ),
                bzl_selects.new(
                    value = "z",
                    kind = "linkedLibrary",
                    condition = "//my_conditions:condition1",
                ),
            ],
            exp = """\
["sqlite3"] + select({
    "//my_conditions:condition1": ["z"],
})\
""",
        ),
        struct(
            msg = "mix of conditions and no conditions, with default",
            khs = {
                "linkedLibrary": bzl_selects.new_kind_handler(
                    transform = lambda v: v,
                    default = [],
                ),
            },
            vals = [
                bzl_selects.new(
                    value = "sqlite3",
                    kind = "linkedLibrary",
                ),
                bzl_selects.new(
                    value = "z",
                    kind = "linkedLibrary",
                    condition = "//my_conditions:condition1",
                ),
                bzl_selects.new(
                    value = "c++",
                    kind = "linkedLibrary",
                    condition = "//my_conditions:condition2",
                ),
            ],
            exp = """\
["sqlite3"] + select({
    "//my_conditions:condition1": ["z"],
    "//my_conditions:condition2": ["c++"],
    "//conditions:default": [],
})\
""",
        ),
    ]
    for t in tests:
        actual = scg.to_starlark(
            bzl_selects.to_starlark(t.vals, kind_handlers = t.khs),
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

to_starlark_test = unittest.make(_to_starlark_test)

def bzl_selects_test_suite():
    return unittest.suite(
        "bzl_selects_tests",
        new_test,
        new_default_test,
        new_from_build_setting_test,
        to_starlark_test,
    )
