"""Analysis tests for transitively raised package minimum OS floors."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

_IOS_MINIMUM_OS_OPTION = "//command_line_option:ios_minimum_os"
_APPLE_PLATFORM_TYPE_OPTION = "//command_line_option:apple_platform_type"

def _probe_basenames(target):
    return sorted([
        file.basename
        for file in target[DefaultInfo].files.to_list()
    ])

def _raised_importer_builds_at_dependency_floor_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    # The importer package declares iOS 13 but its wrapper carries the floor
    # derived from its dependency (iOS 15), so its implementation and the
    # imported implementation both build at 15 under a consumer configured
    # for iOS 18.
    asserts.equals(env, [
        "imported_actual.min-os-15.0.txt",
        "importer_actual.min-os-15.0.txt",
    ], _probe_basenames(target))

    return analysistest.end(env)

raised_importer_builds_at_dependency_floor_test = analysistest.make(
    _raised_importer_builds_at_dependency_floor_test_impl,
    config_settings = {
        _APPLE_PLATFORM_TYPE_OPTION: "ios",
        _IOS_MINIMUM_OS_OPTION: "18.0",
    },
)

def transitive_floor_test_suite(name):
    """Defines the transitive floor analysis test suite.

    Args:
        name: The name of the native test suite.
    """
    raised_importer_builds_at_dependency_floor_test(
        name = "{}_test_0".format(name),
        target_under_test = ":importer_wrapped",
    )
    native.test_suite(
        name = name,
        tests = [
            ":{}_test_0".format(name),
        ],
    )
