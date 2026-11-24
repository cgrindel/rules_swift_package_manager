"""Tests for `swift_package_aliases_lib`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//swiftpkg/internal:starlark_codegen.bzl",
    scg = "starlark_codegen",
)
load(
    "//swiftpkg/internal:swift_package_aliases.bzl",
    "swift_package_aliases_lib",
)

def _build_file_renders_select_test(ctx):
    env = unittest.begin(ctx)

    # Insert out of order to show that the select keys are sorted.
    branches = {}
    branches["@@//b"] = "swiftpkg_foo__slice_1"
    branches["@@//a"] = "swiftpkg_foo__slice_0"
    bld_file = swift_package_aliases_lib.build_file(
        names = ["Foo"],
        branches = branches,
        stale_messages = {},
    )
    expected = """\

alias(
    name = "Foo",
    actual = select(
        {
            "@@//a": "@swiftpkg_foo__slice_0//:Foo",
            "@@//b": "@swiftpkg_foo__slice_1//:Foo",
        },
        no_match_error = "No slice matches the current configuration; tried: @@//a, @@//b",
    ),
    visibility = ["//visibility:public"],
)
"""
    asserts.equals(env, expected, scg.to_starlark(bld_file))

    return unittest.end(env)

build_file_renders_select_test = unittest.make(
    _build_file_renders_select_test,
)

def _stale_branch_adds_stale_target_test(ctx):
    env = unittest.begin(ctx)

    bld_file = swift_package_aliases_lib.build_file(
        names = ["Foo", "_stale_1", "Bar"],
        branches = {
            "@@//a": "swiftpkg_foo__slice_0",
            "@@//b": "",
        },
        stale_messages = {"@@//b": "slice is stale"},
    )
    expected = """\
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "swift_package_stale")

alias(
    name = "Bar",
    actual = select(
        {
            "@@//a": "@swiftpkg_foo__slice_0//:Bar",
            "@@//b": ":_stale_1",
        },
        no_match_error = "No slice matches the current configuration; tried: @@//a, @@//b",
    ),
    visibility = ["//visibility:public"],
)

alias(
    name = "Foo",
    actual = select(
        {
            "@@//a": "@swiftpkg_foo__slice_0//:Foo",
            "@@//b": ":_stale_1",
        },
        no_match_error = "No slice matches the current configuration; tried: @@//a, @@//b",
    ),
    visibility = ["//visibility:public"],
)

swift_package_stale(
    name = "_stale_1",
    message = "slice is stale",
)
"""
    asserts.equals(env, expected, scg.to_starlark(bld_file))

    return unittest.end(env)

stale_branch_adds_stale_target_test = unittest.make(
    _stale_branch_adds_stale_target_test,
)

def _no_match_error_lists_configs_test(ctx):
    env = unittest.begin(ctx)

    code = scg.to_starlark(swift_package_aliases_lib.build_file(
        names = ["Foo"],
        branches = {
            "@@//a": "swiftpkg_foo__slice_0",
            "@@//b": "",
        },
        stale_messages = {"@@//b": "stale"},
    ))
    expected = (
        "no_match_error = \"No slice matches the current configuration; " +
        "tried: @@//a, @@//b\""
    )
    asserts.true(env, expected in code, code)

    return unittest.end(env)

no_match_error_lists_configs_test = unittest.make(
    _no_match_error_lists_configs_test,
)

def _two_stale_configs_get_distinct_targets_test(ctx):
    env = unittest.begin(ctx)

    # Insert out of order to show that the stale targets are numbered in
    # sorted-config order.
    branches = {}
    branches["@@//c"] = ""
    branches["@@//b"] = "swiftpkg_foo__slice_1"
    branches["@@//a"] = ""
    bld_file = swift_package_aliases_lib.build_file(
        names = ["Foo"],
        branches = branches,
        stale_messages = {
            "@@//a": "a is stale",
            "@@//c": "c lacks foo",
        },
    )
    expected = """\
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "swift_package_stale")

alias(
    name = "Foo",
    actual = select(
        {
            "@@//a": ":_stale_1",
            "@@//b": "@swiftpkg_foo__slice_1//:Foo",
            "@@//c": ":_stale_2",
        },
        no_match_error = "No slice matches the current configuration; tried: @@//a, @@//b, @@//c",
    ),
    visibility = ["//visibility:public"],
)

swift_package_stale(
    name = "_stale_1",
    message = "a is stale",
)

swift_package_stale(
    name = "_stale_2",
    message = "c lacks foo",
)
"""
    asserts.equals(env, expected, scg.to_starlark(bld_file))

    return unittest.end(env)

two_stale_configs_get_distinct_targets_test = unittest.make(
    _two_stale_configs_get_distinct_targets_test,
)

def _merge_minimum_os_versions_takes_max_test(ctx):
    env = unittest.begin(ctx)

    actual = swift_package_aliases_lib.merge_minimum_os_versions([
        {
            "package": {"ios": "13.0", "macos": "10.15"},
            "products": {
                "Logging": {"ios": "13.0", "macos": "10.15"},
                "OnlyA": {"ios": "12.0"},
            },
        },
        {
            # `10.9` < `10.15` as versions, though not as strings.
            "package": {"ios": "12.0", "macos": "10.9", "tvos": "13.0"},
            "products": {"Logging": {"ios": "14.0", "macos": "10.9"}},
        },
    ])
    expected = {
        "package": {"ios": "13.0", "macos": "10.15", "tvos": "13.0"},
        "products": {
            "Logging": {"ios": "14.0", "macos": "10.15"},
            "OnlyA": {"ios": "12.0"},
        },
    }
    asserts.equals(env, expected, actual)

    # No branch exports anything.
    asserts.equals(
        env,
        {"package": {}, "products": {}},
        swift_package_aliases_lib.merge_minimum_os_versions([]),
    )

    return unittest.end(env)

merge_minimum_os_versions_takes_max_test = unittest.make(
    _merge_minimum_os_versions_takes_max_test,
)

def swift_package_aliases_test_suite(name = "swift_package_aliases_tests"):
    return unittest.suite(
        name,
        build_file_renders_select_test,
        stale_branch_adds_stale_target_test,
        no_match_error_lists_configs_test,
        two_stale_configs_get_distinct_targets_test,
        merge_minimum_os_versions_takes_max_test,
    )
