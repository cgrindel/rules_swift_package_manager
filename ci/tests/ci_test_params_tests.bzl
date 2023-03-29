"""Tests for `ci_test_params` module."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")

def _sort_integration_test_params_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

sort_integration_test_params_test = unittest.make(_sort_integration_test_params_test)

def _collect_from_deps_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

collect_from_deps_test = unittest.make(_collect_from_deps_test)

def ci_test_params_test_suite(name = "ci_test_params_tests"):
    return unittest.suite(
        name,
        sort_integration_test_params_test,
        collect_from_deps_test,
    )
