"""Tests for `load_statements` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:load_statements.bzl", "load_statements")
load("//swiftpkg/internal:starlark_codegen.bzl", scg = "starlark_codegen")

def _new_test(ctx):
    env = unittest.begin(ctx)

    actual = load_statements.new(
        "@chicken//:foo.bzl",
        "chicken",
        "animal",
        "chicken",
    )

    # Can't easily do equality due to to_starlark_parts.
    asserts.equals(env, "@chicken//:foo.bzl", actual.location)
    asserts.equals(env, ["animal", "chicken"], actual.symbols)

    return unittest.end(env)

new_test = unittest.make(_new_test)

def _to_starlark_parts_test(ctx):
    env = unittest.begin(ctx)

    load_stmt = load_statements.new(
        "@chicken//:foo.bzl",
        "chicken",
        "animal",
    )
    code = scg.to_starlark(load_stmt)
    expected = """\
load("@chicken//:foo.bzl", "animal", "chicken")\
"""
    asserts.equals(env, expected, code)

    return unittest.end(env)

to_starlark_parts_test = unittest.make(_to_starlark_parts_test)

def _uniq_test(ctx):
    env = unittest.begin(ctx)

    load_stmts = [
        load_statements.new("@chicken//:foo.bzl", "chicken"),
        load_statements.new("@chicken//:foo.bzl", "animal"),
        load_statements.new("@smidgen//:bar.bzl", "hello"),
        load_statements.new("@chicken//:foo.bzl", "chicken", "animal"),
    ]
    actual = load_statements.uniq(load_stmts)
    expected = [
        load_statements.new("@chicken//:foo.bzl", "animal", "chicken"),
        load_statements.new("@smidgen//:bar.bzl", "hello"),
    ]
    asserts.equals(env, expected, actual)

    return unittest.end(env)

uniq_test = unittest.make(_uniq_test)

def load_statements_test_suite():
    return unittest.suite(
        "load_statements_tests",
        new_test,
        to_starlark_parts_test,
        uniq_test,
    )
