"""Analysis tests for transitively raised package minimum OS floors."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

_IOS_MINIMUM_OS_OPTION = "//command_line_option:ios_minimum_os"
_APPLE_PLATFORM_TYPE_OPTION = "//command_line_option:apple_platform_type"
_MINIMUM_OS_VERSION_OPTION = "//command_line_option:minimum_os_version"
_PLATFORMS_OPTION = "//command_line_option:platforms"
_EXTRA_TOOLCHAINS_OPTION = "//command_line_option:extra_toolchains"

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

def _off_apple_ignores_package_floors_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    # On Linux the wrappers leave the minimum OS alone, so both probes keep
    # the consumer's value and the iOS 13 importer of an iOS 15 package
    # analyzes instead of failing.
    asserts.equals(env, [
        "imported_actual.min-os-11.0.txt",
        "off_apple_importer_actual.min-os-11.0.txt",
    ], _probe_basenames(target))

    return analysistest.end(env)

off_apple_ignores_package_floors_test = analysistest.make(
    _off_apple_ignores_package_floors_test_impl,
    config_settings = {
        _APPLE_PLATFORM_TYPE_OPTION: "ios",
        _EXTRA_TOOLCHAINS_OPTION: [
            str(Label(":linux_stub_cc_toolchain")),
            str(Label(":linux_stub_swift_toolchain")),
        ],
        _IOS_MINIMUM_OS_OPTION: "11.0",
        _MINIMUM_OS_VERSION_OPTION: "11.0",
        _PLATFORMS_OPTION: str(Label(":linux_x86_64")),
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
    off_apple_ignores_package_floors_test(
        name = "{}_test_1".format(name),
        target_under_test = ":off_apple_importer_wrapped",
    )
    native.test_suite(
        name = name,
        tests = [
            ":{}_test_0".format(name),
            ":{}_test_1".format(name),
        ],
    )
