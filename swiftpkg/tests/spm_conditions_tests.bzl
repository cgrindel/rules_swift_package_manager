"""Tests for `spm_conditions` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:spm_conditions.bzl", "spm_conditions")

def _new_test(ctx):
    env = unittest.begin(ctx)

    actual = spm_conditions.new(
        kind = "platform_types",
        condition = "//path/setting:foo",
        value = ["bar"],
    )
    asserts.equals(env, actual.kind, "platform_types")
    asserts.equals(env, actual.condition, "//path/setting:foo")
    asserts.equals(env, actual.value, ["bar"])

    return unittest.end(env)

new_test = unittest.make(_new_test)

def _new_default_test(ctx):
    env = unittest.begin(ctx)

    actual = spm_conditions.new_default(
        kind = "platform_types",
        value = [],
    )
    expected = spm_conditions.new(
        kind = "platform_types",
        condition = "//conditions:default",
        value = [],
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

new_default_test = unittest.make(_new_default_test)

def spm_conditions_test_suite():
    return unittest.suite(
        "spm_conditions_tests",
        new_test,
        new_default_test,
    )
