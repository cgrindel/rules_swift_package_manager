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
    deps = [
        "//path/to:dep",
    ],
    srcs = [
        "foo.txt",
        "bar.json",
    ],
)\
"""
    asserts.equals(env, expected, code)

    return unittest.end(env)

to_starlark_parts_test = unittest.make(_to_starlark_parts_test)

def build_decls_test_suite():
    return unittest.suite(
        "build_decls_tests",
        to_starlark_parts_test,
    )
