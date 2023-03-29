"""Tests for `bzlmod_modes` module."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")

def _bool_conversion_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

bool_conversion_test = unittest.make(_bool_conversion_test)

def bzlmod_modes_test_suite(name = "bzlmod_modes_tests"):
    return unittest.suite(
        name,
        bool_conversion_test,
    )
