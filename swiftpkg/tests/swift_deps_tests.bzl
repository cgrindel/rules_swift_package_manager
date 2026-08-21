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

def swift_deps_test_suite():
    return unittest.suite(
        "swift_deps_tests",
        bazel_target_mods_by_repo_test,
    )
