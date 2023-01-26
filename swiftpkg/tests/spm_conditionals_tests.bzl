"""Tests for `spm_conditionals` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:spm_conditionals.bzl", "spm_conditionals")

def _new_test(ctx):
    env = unittest.begin(ctx)

    actual = spm_conditionals.new(
        identifier = "platform_types",
        condition = "//path/setting:foo",
        value = ["bar"],
    )
    asserts.equals(env, actual.identifier, "platform_types")
    asserts.equals(env, actual.condition, "//path/setting:foo")
    asserts.equals(env, actual.value, ["bar"])

    return unittest.end(env)

new_test = unittest.make(_new_test)

def _new_default_test(ctx):
    env = unittest.begin(ctx)

    actual = spm_conditionals.new_default(
        identifier = "platform_types",
        value = [],
    )
    expected = spm_conditionals.new(
        identifier = "platform_types",
        condition = "//conditions:default",
        value = [],
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

new_default_test = unittest.make(_new_default_test)

def spm_conditionals_test_suite():
    return unittest.suite(
        "spm_conditionals_tests",
        new_test,
        new_default_test,
    )
