"""Analysis tests for `swift_package_stale`."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _fails_with_message_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(
        env,
        "slice `swift/macos` (config `@platforms//os:macos`) is stale",
    )
    return analysistest.end(env)

_fails_with_message_test = analysistest.make(
    _fails_with_message_test_impl,
    expect_failure = True,
)

def swift_package_stale_test_suite(name = "swift_package_stale_tests"):
    """Declares the `swift_package_stale` analysis tests.

    Args:
        name: The name of the test suite.
    """
    _fails_with_message_test(
        name = "fails_with_message_test",
        target_under_test = ":swift_package_stale_fixture",
    )
    native.test_suite(
        name = name,
        tests = [":fails_with_message_test"],
    )
