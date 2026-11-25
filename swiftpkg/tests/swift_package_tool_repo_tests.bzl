"""Tests for `swift_package_tool_repo_lib`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//swiftpkg/internal:starlark_codegen.bzl",
    scg = "starlark_codegen",
)
load(
    "//swiftpkg/internal:swift_package_tool_repo.bzl",
    "swift_package_tool_repo_lib",
)

_MACOS_SLICE = struct(
    config = "@@platforms//os:macos",
    config_value = "@@platforms//os:macos",
    dir = "swift/macos",
    package_value = "//swift/macos",
)

_LINUX_SLICE = struct(
    config = "@@platforms//os:linux",
    config_value = "@@platforms//os:linux",
    dir = "swift/linux",
    package_value = "//swift/linux",
)

_PATCH = "@@//third_party:fix.patch"

def _text(patch_specs, patch_files):
    bld_file = swift_package_tool_repo_lib.build_file(
        slices = [_MACOS_SLICE, _LINUX_SLICE],
        package_path = "swift/Package.swift",
        swift_label = "@@//swift:Package.swift",
        flags = "cache_path=.cache\n",
        patch_specs = patch_specs,
        patch_files = patch_files,
    )
    return scg.to_starlark(bld_file)

def _assert_contains(env, text, fragment):
    asserts.true(
        env,
        fragment in text,
        "Expected to find:\n{}\nin:\n{}".format(fragment, text),
    )

def _build_file_declares_three_targets_test(ctx):
    env = unittest.begin(ctx)

    text = _text(
        patch_specs = {
            "swift-log": struct(files = [_PATCH], args = ["-p1"]),
        },
        patch_files = [_PATCH],
    )
    _assert_contains(
        env,
        text,
        """\
load("@rules_swift_package_manager//swiftpkg/internal:swift_package_tool_rule.bzl", "swift_package_tool_rule")
""",
    )
    for cmd in ["resolve", "update", "cache"]:
        _assert_contains(
            env,
            text,
            """\
swift_package_tool_rule(
    name = "{cmd}",
    args = [
        "{cmd}",
        "--package",
        "swift/Package.swift",
        "--swift-label",
        "@@//swift:Package.swift",
        "--slice",
    ] + select(
        {{
            "@@platforms//os:linux": ["swift/linux"],
            "@@platforms//os:macos": ["swift/macos"],
        }},
""".format(cmd = cmd),
        )
    _assert_contains(
        env,
        text,
        """\
        "--flag",
        "cache_path=.cache",
        "--patch",
        "swift-log=$(rootpath @@//third_party:fix.patch)",
        "--patch-args",
        "swift-log=-p1",
    ],
    data = ["@@//third_party:fix.patch"],
    visibility = ["//visibility:public"],
)""",
    )

    # Declared in this order: resolve, update, cache.
    order = [
        text.find('name = "{}"'.format(cmd))
        for cmd in ["resolve", "update", "cache"]
    ]
    asserts.equals(env, sorted(order), order, "Unexpected target order")

    return unittest.end(env)

build_file_declares_three_targets_test = unittest.make(
    _build_file_declares_three_targets_test,
)

def _patch_args_default_test(ctx):
    env = unittest.begin(ctx)

    text = _text(
        patch_specs = {"swift-log": struct(files = [_PATCH], args = [])},
        patch_files = [_PATCH],
    )
    _assert_contains(env, text, '"--patch-args",\n        "swift-log=-p0",')

    return unittest.end(env)

patch_args_default_test = unittest.make(_patch_args_default_test)

def _no_patches_omits_data_test(ctx):
    env = unittest.begin(ctx)

    text = _text(patch_specs = {}, patch_files = [])
    asserts.false(env, "data =" in text, "Unexpected data:\n" + text)

    return unittest.end(env)

no_patches_omits_data_test = unittest.make(_no_patches_omits_data_test)

def _build_file_from_attr_decodes_json_test(ctx):
    env = unittest.begin(ctx)

    attr = struct(
        slices = json.encode([{
            "config": _MACOS_SLICE.config,
            "config_value": _MACOS_SLICE.config_value,
            "dir": _MACOS_SLICE.dir,
            "package_value": _MACOS_SLICE.package_value,
        }]),
        package_path = "swift/Package.swift",
        swift_label = "@@//swift:Package.swift",
        flags = "",
        patch_specs = json.encode({
            "swift-log": {"args": [], "files": [_PATCH]},
        }),
        patch_files = [Label(_PATCH)],
    )
    text = scg.to_starlark(
        swift_package_tool_repo_lib.build_file_from_attr(attr),
    )
    _assert_contains(env, text, '"@@platforms//os:macos": ["swift/macos"],')
    _assert_contains(env, text, '"swift-log=$(rootpath @@//third_party:fix.patch)",')
    _assert_contains(env, text, 'data = ["@@//third_party:fix.patch"],')

    return unittest.end(env)

build_file_from_attr_decodes_json_test = unittest.make(
    _build_file_from_attr_decodes_json_test,
)

def swift_package_tool_repo_test_suite(name = "swift_package_tool_repo_tests"):
    return unittest.suite(
        name,
        build_file_declares_three_targets_test,
        patch_args_default_test,
        no_patches_omits_data_test,
        build_file_from_attr_decodes_json_test,
    )
