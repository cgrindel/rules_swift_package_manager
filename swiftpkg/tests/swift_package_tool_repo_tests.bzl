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

def _v2_text(patch_specs, patch_files):
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

def _v2_build_file_declares_three_targets_test(ctx):
    env = unittest.begin(ctx)

    text = _v2_text(
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

v2_build_file_declares_three_targets_test = unittest.make(
    _v2_build_file_declares_three_targets_test,
)

def _v2_patch_args_default_test(ctx):
    env = unittest.begin(ctx)

    text = _v2_text(
        patch_specs = {"swift-log": struct(files = [_PATCH], args = [])},
        patch_files = [_PATCH],
    )
    _assert_contains(env, text, '"--patch-args",\n        "swift-log=-p0",')

    return unittest.end(env)

v2_patch_args_default_test = unittest.make(_v2_patch_args_default_test)

def _v2_no_patches_omits_data_test(ctx):
    env = unittest.begin(ctx)

    text = _v2_text(patch_specs = {}, patch_files = [])
    asserts.false(env, "data =" in text, "Unexpected data:\n" + text)

    return unittest.end(env)

v2_no_patches_omits_data_test = unittest.make(_v2_no_patches_omits_data_test)

def _v2_build_file_from_attr_decodes_json_test(ctx):
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

v2_build_file_from_attr_decodes_json_test = unittest.make(
    _v2_build_file_from_attr_decodes_json_test,
)

def _v1_unchanged_test(ctx):
    env = unittest.begin(ctx)

    attr = struct(
        package = "swift/Package.swift",
        build_path = ".build",
        cache_path = ".cache",
        config_path = ".config",
        security_path = ".security",
        manifest_caching = True,
        dependency_caching = False,
        manifest_cache = "shared",
        replace_scm_with_registry = False,
        use_registry_identity_for_scm = True,
        netrc = "//:.netrc",
        registries = None,
        env = {"FOO": "bar"},
    )
    actual = scg.to_starlark(
        swift_package_tool_repo_lib.v1_build_file(attr, data = [":.netrc"]),
    )
    expected_args = """\
[
        "--cmd",
        "{cmd}",
        "--package_path",
        "swift",
        "--build_path",
        ".build",
        "--cache_path",
        ".cache",
        "--config_path",
        ".config",
        "--security_path",
        ".security",
        "--enable_build_manifest_caching",
        "true",
        "--enable_dependency_cache",
        "false",
        "--manifest_cache",
        "shared",
        "--replace_scm_with_registry",
        "false",
        "--use_registry_identity_for_scm",
        "true",
        "--netrc_file",
        "$(rootpath :.netrc)",
        "--env",
        "FOO=bar",
        "--manifest_swiftc_flags",
        "-Xbuild-tools-swiftc -DBAZEL",
    ]"""
    expected = """\
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_worker_binary")

swift_worker_binary(
    name = "update",
    data = [":.netrc"],
    extra_args = {update},
    tool = "@rules_swift_package_manager//tools/swift_package_cmd",
)

swift_worker_binary(
    name = "resolve",
    data = [":.netrc"],
    extra_args = {resolve},
    tool = "@rules_swift_package_manager//tools/swift_package_cmd",
)
""".format(
        update = expected_args.format(cmd = "update"),
        resolve = expected_args.format(cmd = "resolve"),
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

v1_unchanged_test = unittest.make(_v1_unchanged_test)

def swift_package_tool_repo_test_suite(name = "swift_package_tool_repo_tests"):
    return unittest.suite(
        name,
        v2_build_file_declares_three_targets_test,
        v2_patch_args_default_test,
        v2_no_patches_omits_data_test,
        v2_build_file_from_attr_decodes_json_test,
        v1_unchanged_test,
    )
