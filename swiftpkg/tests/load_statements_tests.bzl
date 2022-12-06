"""Tests for `load_statements` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:load_statements.bzl", "load_statements")

def _new_test(ctx):
    env = unittest.begin(ctx)

    actual = load_statements.new(
        "@chicken//:foo.bzl",
        "chicken",
        "animal",
        "chicken",
    )
    expected = struct(
        location = "@chicken//:foo.bzl",
        symbols = ["animal", "chicken"],
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

new_test = unittest.make(_new_test)

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
        uniq_test,
    )
