"""Tests for `validations` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:validations.bzl", "validations")

def _in_list_test(ctx):
    env = unittest.begin(ctx)

    valid_values = ["foo", "bar"]
    asserts.true(env, validations.in_list(valid_values, "bar"))
    asserts.false(env, validations.in_list(valid_values, "does_not_exist"))

    return unittest.end(env)

in_list_test = unittest.make(_in_list_test)

def validations_test_suite():
    return unittest.suite(
        "validations_tests",
        in_list_test,
    )
