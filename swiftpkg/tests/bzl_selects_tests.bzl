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
        struct(
            msg = "with values_map_fn",
            bs = pkginfos.new_build_setting(
                kind = "define",
                values = ["CHICKEN=Foo"],
            ),
            values_map_fn = lambda x: x + "Bar",
            exp = [
                bzl_selects.new(value = "CHICKEN=FooBar", kind = "define"),
            ],
        ),
    ]
    for t in tests:
        values_map_fn = getattr(t, "values_map_fn", None)
        actual = bzl_selects.new_from_build_setting(
            t.bs,
            values_map_fn = values_map_fn,
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

new_from_build_setting_test = unittest.make(_new_from_build_setting_test)

def _to_starlark_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "string values",
            khs = {},
            vals = ["-DFoo", "-Xcc", "-DFoo"],
            exp = """\
[
    "-DFoo",
    "-Xcc",
    "-DFoo",
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
            khs = {
                # If a default is not specified, it is assumed to be [].
                # Hence, we need to specify None.
                "linkedLibrary": bzl_selects.new_kind_handler(default = None),
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
        struct(
            msg = "multiple of the same condition",
            khs = {},
            vals = [
                bzl_selects.new(
                    value = "-DFoo",
                    kind = "mykind",
                    condition = "//myconditions:alpha",
                ),
                bzl_selects.new(
                    value = "-DBar",
                    kind = "mykind",
                    condition = "//myconditions:beta",
                ),
                bzl_selects.new(
                    value = "-DZoo",
                    kind = "mykind",
                    condition = "//myconditions:alpha",
                ),
                bzl_selects.new(
                    value = "-Xcc",
                    kind = "mykind",
                    condition = "//myconditions:alpha",
                ),
                bzl_selects.new(
                    value = "-DFoo",
                    kind = "mykind",
                    condition = "//myconditions:alpha",
                ),
            ],
            exp = """\
select({
    "//myconditions:alpha": [
        "-DFoo",
        "-DZoo",
        "-Xcc",
        "-DFoo",
    ],
    "//myconditions:beta": ["-DBar"],
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

def _new_kind_handler_test(ctx):
    env = unittest.begin(ctx)

    value = "foo"

    tests = [
        struct(
            msg = "no parameters",
            transform = None,
            default = None,
            exp_tx = "foo",
            exp_def = None,
        ),
        struct(
            msg = "with parameters",
            transform = lambda v: v + "bar",
            default = [],
            exp_tx = "foobar",
            exp_def = [],
        ),
    ]
    for t in tests:
        kh = bzl_selects.new_kind_handler(
            transform = t.transform,
            default = t.default,
        )
        actual_tx = kh.transform(value)
        asserts.equals(env, t.exp_tx, actual_tx, t.msg + " transform")
        asserts.equals(env, t.exp_def, kh.default, t.msg + " default")

    return unittest.end(env)

new_kind_handler_test = unittest.make(_new_kind_handler_test)

def _new_from_target_dependency_condition_test(ctx):
    env = unittest.begin(ctx)

    kind = "_foo"
    labels = ["@baz//:apple", "@baz//:pear"]
    tests = [
        struct(
            msg = "no condition",
            c = None,
            exp = [
                bzl_selects.new(
                    kind = kind,
                    value = labels,
                    condition = None,
                ),
            ],
        ),
        struct(
            msg = "with condition",
            c = pkginfos.new_target_dependency_condition(
                platforms = ["ios", "tvos"],
            ),
            exp = [
                bzl_selects.new(
                    kind = kind,
                    value = labels,
                    condition = c,
                )
                for c in [
                    spm_platforms.label("ios"),
                    spm_platforms.label("tvos"),
                ]
            ],
        ),
    ]
    for t in tests:
        actual = bzl_selects.new_from_target_dependency_condition(
            kind = kind,
            labels = labels,
            condition = t.c,
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

new_from_target_dependency_condition_test = unittest.make(_new_from_target_dependency_condition_test)

def bzl_selects_test_suite():
    return unittest.suite(
        "bzl_selects_tests",
        new_test,
        new_from_build_setting_test,
        to_starlark_test,
        new_kind_handler_test,
        new_from_target_dependency_condition_test,
    )
