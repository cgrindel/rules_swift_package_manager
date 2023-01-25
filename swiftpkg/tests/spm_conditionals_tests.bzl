"""Tests for `spm_conditionals` module."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")

def _build_setting_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

build_setting_test = unittest.make(_build_setting_test)

def spm_conditionals_test_suite():
    return unittest.suite(
        "spm_conditionals_tests",
        build_setting_test,
    )
