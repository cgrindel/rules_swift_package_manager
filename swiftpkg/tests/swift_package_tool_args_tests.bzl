"""Tests for `swift_package_tool_args` and `swift_package_tool_rule`."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load(
    "//swiftpkg/internal:starlark_codegen.bzl",
    scg = "starlark_codegen",
)
load(
    "//swiftpkg/internal:swift_package_tool_args.bzl",
    "swift_package_tool_args",
)

_MACOS_SLICE = struct(
    config = "@@platforms//os:macos",
    config_value = "@platforms//os:macos",
    dir = "swift/macos",
    package_value = "//swift/macos",
)

_LINUX_SLICE = struct(
    config = "@@platforms//os:linux",
    config_value = "@platforms//os:linux",
    dir = "swift/linux",
    package_value = "//swift/linux",
)

_TARGET_OS_SELECT = """\
select({
        "@@platforms//os:ios": ["ios"],
        "@@platforms//os:linux": ["linux"],
        "@@platforms//os:macos": ["macos"],
        "@@platforms//os:tvos": ["tvos"],
        "@@platforms//os:visionos": ["visionos"],
        "@@platforms//os:watchos": ["watchos"],
        "//conditions:default": ["unknown"],
    })"""

def _render_decl(**kwargs):
    segments = swift_package_tool_args.render(**kwargs)
    decl = build_decls.new(
        "swift_package_tool_rule",
        kwargs["cmd"],
        attrs = {"args": swift_package_tool_args.to_expr(segments)},
    )
    return scg.to_starlark(decl)

def _single_slice_test(ctx):
    env = unittest.begin(ctx)

    actual = _render_decl(
        cmd = "cache",
        package_path = "Package.swift",
        swift_label = "//swift:Package.swift",
        slices = [_MACOS_SLICE],
        flags = "",
        patch_specs = {},
    )
    expected = """\
swift_package_tool_rule(
    name = "cache",
    args = [
        "cache",
        "--package",
        "Package.swift",
        "--swift-label",
        "//swift:Package.swift",
        "--slice",
    ] + select(
        {
            "@@platforms//os:macos": ["swift/macos"],
        },
        no_match_error = "No slice matches the current configuration; tried: @@platforms//os:macos",
    ) + ["--slice-package"] + select(
        {
            "@@platforms//os:macos": ["//swift/macos"],
        },
        no_match_error = "No slice matches the current configuration; tried: @@platforms//os:macos",
    ) + ["--config"] + select(
        {
            "@@platforms//os:macos": ["@platforms//os:macos"],
        },
        no_match_error = "No slice matches the current configuration; tried: @@platforms//os:macos",
    ) + ["--target-os"] + """ + _TARGET_OS_SELECT + """,
)"""
    asserts.equals(env, expected, actual)

    return unittest.end(env)

single_slice_test = unittest.make(_single_slice_test)

def _two_slices_select_test(ctx):
    env = unittest.begin(ctx)

    # Passed out of order to show that the select keys are sorted.
    actual = _render_decl(
        cmd = "update",
        package_path = "swift/Package.swift",
        swift_label = "//:swift",
        slices = [_MACOS_SLICE, _LINUX_SLICE],
        flags = "",
        patch_specs = {},
    )
    no_match = (
        "No slice matches the current configuration; tried: " +
        "@@platforms//os:linux, @@platforms//os:macos"
    )
    expected = """\
swift_package_tool_rule(
    name = "update",
    args = [
        "update",
        "--package",
        "swift/Package.swift",
        "--swift-label",
        "//:swift",
        "--slice",
    ] + select(
        {
            "@@platforms//os:linux": ["swift/linux"],
            "@@platforms//os:macos": ["swift/macos"],
        },
        no_match_error = "{no_match}",
    ) + ["--slice-package"] + select(
        {
            "@@platforms//os:linux": ["//swift/linux"],
            "@@platforms//os:macos": ["//swift/macos"],
        },
        no_match_error = "{no_match}",
    ) + ["--config"] + select(
        {
            "@@platforms//os:linux": ["@platforms//os:linux"],
            "@@platforms//os:macos": ["@platforms//os:macos"],
        },
        no_match_error = "{no_match}",
    ) + ["--target-os"] + """.replace("{no_match}", no_match) + _TARGET_OS_SELECT + """,
)"""
    asserts.equals(env, expected, actual)

    return unittest.end(env)

two_slices_select_test = unittest.make(_two_slices_select_test)

def _flags_preserve_order_test(ctx):
    env = unittest.begin(ctx)

    # The flags arrive already sorted from `staleness.render_flags`; the
    # renderer keeps their order and emits one `--flag` pair per line.
    for flags in [
        "enable_traits=true\nresolve_strategy=default\n",
        ["enable_traits=true", "resolve_strategy=default"],
    ]:
        segments = swift_package_tool_args.render(
            cmd = "resolve",
            package_path = "Package.swift",
            swift_label = "//:swift",
            slices = [_MACOS_SLICE],
            flags = flags,
            patch_specs = {},
        )
        actual = scg.to_starlark(segments[-1])
        expected = """\
[
    "--flag",
    "enable_traits=true",
    "--flag",
    "resolve_strategy=default",
]\
"""
        asserts.equals(env, expected, actual)

    return unittest.end(env)

flags_preserve_order_test = unittest.make(_flags_preserve_order_test)

def _patches_use_rootpath_test(ctx):
    env = unittest.begin(ctx)

    segments = swift_package_tool_args.render(
        cmd = "cache",
        package_path = "Package.swift",
        swift_label = "//:swift",
        slices = [_MACOS_SLICE],
        flags = "",
        patch_specs = {
            "swift-log": struct(
                files = ["//patches:log.patch"],
                args = [],
            ),
            "swift-nio": struct(
                files = ["//patches:nio_a.patch", "//patches:nio_b.patch"],
                args = ["-p1", "--verbose"],
            ),
        },
    )
    actual = scg.to_starlark(segments[-1])
    expected = """\
[
    "--patch",
    "swift-log=$(rootpath //patches:log.patch)",
    "--patch",
    "swift-nio=$(rootpath //patches:nio_a.patch)",
    "--patch",
    "swift-nio=$(rootpath //patches:nio_b.patch)",
    "--patch-args",
    "swift-log=-p0",
    "--patch-args",
    "swift-nio=-p1",
    "--patch-args",
    "swift-nio=--verbose",
]\
"""
    asserts.equals(env, expected, actual)

    return unittest.end(env)

patches_use_rootpath_test = unittest.make(_patches_use_rootpath_test)

def _rule_sets_run_env_and_runfiles_test_impl(ctx):
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)
    swift_tool = target[RunEnvironmentInfo].environment["RSPM_SWIFT_TOOL"]
    asserts.true(
        env,
        swift_tool.endswith("tools/swift"),
        "expected RSPM_SWIFT_TOOL to end with tools/swift: {}".format(
            swift_tool,
        ),
    )

    default_info = target[DefaultInfo]
    runfiles = [
        f.short_path
        for f in default_info.default_runfiles.files.to_list()
    ]
    asserts.true(
        env,
        "tools/swift" in runfiles,
        "expected the swift wrapper in runfiles: {}".format(runfiles),
    )
    asserts.true(
        env,
        "tools/swift_deps_tool/swift_deps_tool" in runfiles,
        "expected the tool binary in runfiles: {}".format(runfiles),
    )
    asserts.equals(
        env,
        "swift_package_tool_rule_fixture",
        default_info.files_to_run.executable.basename,
    )

    return analysistest.end(env)

_rule_sets_run_env_and_runfiles_test = analysistest.make(
    _rule_sets_run_env_and_runfiles_test_impl,
)

def swift_package_tool_args_test_suite(name = "swift_package_tool_args_tests"):
    """Declares the `swift_package_tool_args` and rule tests.

    Args:
        name: The name of the test suite.
    """
    _rule_sets_run_env_and_runfiles_test(
        name = "rule_sets_run_env_and_runfiles_test",
        target_under_test = ":swift_package_tool_rule_fixture",
    )
    unittest.suite(
        name + "_unit",
        single_slice_test,
        two_slices_select_test,
        flags_preserve_order_test,
        patches_use_rootpath_test,
    )
    native.test_suite(
        name = name,
        tests = [
            ":" + name + "_unit",
            ":rule_sets_run_env_and_runfiles_test",
        ],
    )
