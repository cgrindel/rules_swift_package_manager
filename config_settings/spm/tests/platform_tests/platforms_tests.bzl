"""Tests for `platforms` module."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")

def _is_supported_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

is_supported_test = unittest.make(_is_supported_test)

def _supported_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

supported_test = unittest.make(_supported_test)

def platforms_test_suite(name = "platforms_tests"):
    return unittest.suite(
        name,
        is_supported_test,
        supported_test,
    )
