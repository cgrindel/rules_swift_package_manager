"""Tests for `ci_test_params` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//ci/internal:ci_test_params.bzl", "ci_test_params")
load("//ci/internal:providers.bzl", "CITestParamsInfo")

def _sort_integration_test_params_test(ctx):
    env = unittest.begin(ctx)

    itps = [
        ci_test_params.new_integration_test_params(
            test = "//:zebra",
            os = "macos",
            bzlmod_mode = "enabled",
        ),
        ci_test_params.new_integration_test_params(
            test = "//:zebra",
            os = "macos",
            bzlmod_mode = "disabled",
        ),
        ci_test_params.new_integration_test_params(
            test = "//:apple",
            os = "macos",
            bzlmod_mode = "enabled",
        ),
    ]
    expected = [
        ci_test_params.new_integration_test_params(
            test = "//:apple",
            os = "macos",
            bzlmod_mode = "enabled",
        ),
        ci_test_params.new_integration_test_params(
            test = "//:zebra",
            os = "macos",
            bzlmod_mode = "disabled",
        ),
        ci_test_params.new_integration_test_params(
            test = "//:zebra",
            os = "macos",
            bzlmod_mode = "enabled",
        ),
    ]
    actual = ci_test_params.sort_integration_test_params(itps)
    asserts.equals(env, expected, actual)

    return unittest.end(env)

sort_integration_test_params_test = unittest.make(_sort_integration_test_params_test)

def _collect_from_deps_test(ctx):
    env = unittest.begin(ctx)

    deps = [
        {CITestParamsInfo: CITestParamsInfo(
            integration_test_params = depset([
                ci_test_params.new_integration_test_params(
                    test = "//:zebra",
                    os = "macos",
                    bzlmod_mode = "enabled",
                ),
            ]),
        )},
        {CITestParamsInfo: CITestParamsInfo(
            integration_test_params = depset([
                ci_test_params.new_integration_test_params(
                    test = "//:apple",
                    os = "linux",
                    bzlmod_mode = "disabled",
                ),
            ]),
        )},
    ]
    actual = ci_test_params.collect_from_deps(deps)
    actual_itps = ci_test_params.sort_integration_test_params(
        actual.integration_test_params.to_list(),
    )
    expected_itps = [
        ci_test_params.new_integration_test_params(
            test = "//:apple",
            os = "linux",
            bzlmod_mode = "disabled",
        ),
        ci_test_params.new_integration_test_params(
            test = "//:zebra",
            os = "macos",
            bzlmod_mode = "enabled",
        ),
    ]
    asserts.equals(env, expected_itps, actual_itps)

    return unittest.end(env)

collect_from_deps_test = unittest.make(_collect_from_deps_test)

def ci_test_params_test_suite(name = "ci_test_params_tests"):
    return unittest.suite(
        name,
        sort_integration_test_params_test,
        collect_from_deps_test,
    )
