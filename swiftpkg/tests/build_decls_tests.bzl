"""Tests for `build_decls` API"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:starlark_codegen.bzl", scg = "starlark_codegen")

def _to_starlark_parts_test(ctx):
    env = unittest.begin(ctx)

    bd = build_decls.new(
        kind = "smidgen_library",
        name = "chicken",
        attrs = {
            "deps": ["//path/to:dep"],
            "srcs": ["foo.txt", "bar.json"],
        },
        comments = [
            "# Comment above the declaration.",
        ],
    )

    code = scg.to_starlark(bd)
    expected = """\
# Comment above the declaration.
smidgen_library(
    name = "chicken",
    deps = ["//path/to:dep"],
    srcs = [
        "foo.txt",
        "bar.json",
    ],
)\
"""
    asserts.equals(env, expected, code)

    return unittest.end(env)

to_starlark_parts_test = unittest.make(_to_starlark_parts_test)

def _uniq_test(ctx):
    env = unittest.begin(ctx)

    decls = [
        build_decls.new("smidgen_library", "zzz"),
        build_decls.new("chicken_library", "goodbye"),
        build_decls.new("smidgen_library", "hello"),
    ]
    actual = build_decls.uniq(decls)
    expected = [
        build_decls.new("chicken_library", "goodbye"),
        build_decls.new("smidgen_library", "hello"),
        build_decls.new("smidgen_library", "zzz"),
    ]
    asserts.equals(env, expected, actual)

    return unittest.end(env)

uniq_test = unittest.make(_uniq_test)

def _get_test(ctx):
    env = unittest.begin(ctx)

    horse_decl = build_decls.new("smidgen_library", "horse")
    decls = [
        build_decls.new("chicken_binary", "goodbye"),
        build_decls.new("chicken_library", "hello"),
        horse_decl,
    ]

    actual = build_decls.get(decls, "does_not_exist", fail_if_not_found = False)
    asserts.equals(env, None, actual)

    actual = build_decls.get(decls, "horse", fail_if_not_found = False)
    asserts.equals(env, horse_decl, actual)

    return unittest.end(env)

get_test = unittest.make(_get_test)

def build_decls_test_suite():
    return unittest.suite(
        "build_decls_tests",
        to_starlark_parts_test,
        uniq_test,
        get_test,
    )
