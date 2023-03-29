"""Tests for `bzlmod_modes` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//ci/internal:bzlmod_modes.bzl", "bzlmod_modes")

def _bool_conversion_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "enabled",
            mode = "enabled",
            bool = True,
        ),
        struct(
            msg = "disabled",
            mode = "disabled",
            bool = False,
        ),
    ]
    for t in tests:
        actual_bool = bzlmod_modes.to_bool(t.mode)
        asserts.equals(env, t.bool, actual_bool, t.msg)
        actual_mode = bzlmod_modes.from_bool(t.bool)
        asserts.equals(env, t.mode, actual_mode, t.msg)

    return unittest.end(env)

bool_conversion_test = unittest.make(_bool_conversion_test)

def bzlmod_modes_test_suite(name = "bzlmod_modes_tests"):
    return unittest.suite(
        name,
        bool_conversion_test,
    )
