"""Tests for the `swift_deps` bzlmod extension helpers."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/bzlmod:swift_deps.bzl", "swift_deps_test_utils")

def _new_tags(
        bazel_target_set = [],
        bazel_target_set_select = [],
        bazel_target_add = [],
        bazel_target_add_select = []):
    return struct(
        bazel_target_add = bazel_target_add,
        bazel_target_add_select = bazel_target_add_select,
        bazel_target_set = bazel_target_set,
        bazel_target_set_select = bazel_target_set_select,
    )

def _new_module_ctx(modules):
    return struct(modules = modules)

def _bazel_target_mods_by_repo_test(ctx):
    env = unittest.begin(ctx)

    # No tags anywhere.
    actual = swift_deps_test_utils.bazel_target_mods_by_repo(
        _new_module_ctx([
            struct(is_root = True, name = "my_app", tags = _new_tags()),
            struct(is_root = False, name = "some_dep", tags = _new_tags()),
        ]),
    )
    asserts.equals(env, {}, actual)

    # Tags from the root module are collected and routed by repository name. A
    # non-root module without these tags is simply skipped.
    actual = swift_deps_test_utils.bazel_target_mods_by_repo(
        _new_module_ctx([
            struct(
                is_root = True,
                name = "my_app",
                tags = _new_tags(
                    bazel_target_set = [struct(
                        target = "@swiftpkg_foo//:Bar.rspm.__impl",
                        attr = "alwayslink",
                        value = "False",
                    )],
                    bazel_target_add = [struct(
                        target = "@swiftpkg_baz//:Qux.rspm.__impl",
                        attr = "copts",
                        values = ["-DBAZ"],
                    )],
                    bazel_target_add_select = [struct(
                        target = "@swiftpkg_foo//:Bar.rspm.__impl",
                        attr = "copts",
                        values = {"//:release_build": ["-O2"]},
                    )],
                ),
            ),
            struct(is_root = False, name = "some_dep", tags = _new_tags()),
        ]),
    )
    asserts.equals(
        env,
        ["swiftpkg_baz", "swiftpkg_foo"],
        sorted(actual.keys()),
    )
    asserts.equals(
        env,
        [
            {
                "attr": "alwayslink",
                "target": "Bar.rspm.__impl",
                "value": "False",
                "verb": "set",
            },
            {
                "attr": "copts",
                "target": "Bar.rspm.__impl",
                "values": {"@@//:release_build": ["-O2"]},
                "verb": "add_select",
            },
        ],
        actual["swiftpkg_foo"],
    )
    asserts.equals(
        env,
        [{
            "attr": "copts",
            "target": "Qux.rspm.__impl",
            "values": ["-DBAZ"],
            "verb": "add",
        }],
        actual["swiftpkg_baz"],
    )

    return unittest.end(env)

bazel_target_mods_by_repo_test = unittest.make(_bazel_target_mods_by_repo_test)

def _non_root_target_mods_error_test(ctx):
    env = unittest.begin(ctx)

    # A non-root module with no target modification tags is fine.
    asserts.equals(
        env,
        None,
        swift_deps_test_utils.non_root_target_mods_error(
            "some_dep",
            [
                struct(verb = "set", tags = []),
                struct(verb = "add", tags = []),
            ],
        ),
    )

    error = swift_deps_test_utils.non_root_target_mods_error(
        "some_dep",
        [
            struct(verb = "set", tags = []),
            struct(verb = "set_select", tags = [struct()]),
            struct(verb = "add", tags = [struct()]),
            struct(verb = "add_select", tags = []),
        ],
    )
    asserts.true(env, error != None, "Expected an error.")
    asserts.true(
        env,
        error.find("some_dep") > -1,
        "Expected the error to name the offending module.",
    )
    asserts.true(
        env,
        error.find("bazel_target_set_select, bazel_target_add") > -1,
        "Expected the error to list the declared tags.",
    )

    return unittest.end(env)

non_root_target_mods_error_test = unittest.make(_non_root_target_mods_error_test)

def _build_file_conflict_error_test(ctx):
    env = unittest.begin(ctx)

    mods = "[{\"verb\": \"add\"}]"

    # Only the combination of a `build_file` override and target modifications
    # is a conflict.
    for t in [
        struct(msg = "no build file, no mods", build_file = None, mods = ""),
        struct(msg = "no build file, mods", build_file = None, mods = mods),
        struct(
            msg = "build file, no mods",
            build_file = "//:my.BUILD.bazel",
            mods = "",
        ),
    ]:
        asserts.equals(
            env,
            None,
            swift_deps_test_utils.build_file_conflict_error(
                "swift-log",
                t.build_file,
                t.mods,
            ),
            t.msg,
        )

    error = swift_deps_test_utils.build_file_conflict_error(
        "swift-log",
        "//:my.BUILD.bazel",
        mods,
    )
    asserts.true(env, error != None, "Expected an error.")
    asserts.true(
        env,
        error.find("swift-log") > -1,
        "Expected the error to name the package.",
    )
    asserts.true(
        env,
        error.find("build_file") > -1,
        "Expected the error to mention the `build_file` override.",
    )

    return unittest.end(env)

build_file_conflict_error_test = unittest.make(_build_file_conflict_error_test)

def swift_deps_test_suite():
    return unittest.suite(
        "swift_deps_tests",
        bazel_target_mods_by_repo_test,
        build_file_conflict_error_test,
        non_root_target_mods_error_test,
    )
