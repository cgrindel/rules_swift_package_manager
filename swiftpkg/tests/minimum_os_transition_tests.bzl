"""Tests for `minimum_os_transition`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:minimum_os_transition.bzl", "minimum_os_transition")

_APPLE_PLATFORM_TYPE_OPTION = "//command_line_option:apple_platform_type"
_IOS_MINIMUM_OS_OPTION = "//command_line_option:ios_minimum_os"
_MACOS_MINIMUM_OS_OPTION = "//command_line_option:macos_minimum_os"
_TVOS_MINIMUM_OS_OPTION = "//command_line_option:tvos_minimum_os"
_WATCHOS_MINIMUM_OS_OPTION = "//command_line_option:watchos_minimum_os"
_VISIONOS_MINIMUM_OS_OPTION = "//command_line_option:minimum_os_version"

def _settings(platform_type, ios = "18.0", visionos = "2.0"):
    return {
        _APPLE_PLATFORM_TYPE_OPTION: platform_type,
        _IOS_MINIMUM_OS_OPTION: ios,
        _MACOS_MINIMUM_OS_OPTION: "15.0",
        _TVOS_MINIMUM_OS_OPTION: "18.0",
        _WATCHOS_MINIMUM_OS_OPTION: "11.0",
        _VISIONOS_MINIMUM_OS_OPTION: visionos,
    }

def _attrs():
    return struct(
        ios_minimum_os = "13.0",
        macos_minimum_os = "10.15",
        tvos_minimum_os = "13.0",
        visionos_minimum_os = "1.0",
        watchos_minimum_os = "6.0",
    )

def _sets_active_platform_to_package_minimum_test(ctx):
    env = unittest.begin(ctx)

    actual = minimum_os_transition.transition_outputs(
        settings = _settings("ios"),
        attr = _attrs(),
    )

    asserts.equals(env, "13.0", actual[_IOS_MINIMUM_OS_OPTION])
    asserts.equals(env, "15.0", actual[_MACOS_MINIMUM_OS_OPTION])
    asserts.equals(env, "18.0", actual[_TVOS_MINIMUM_OS_OPTION])
    asserts.equals(env, "11.0", actual[_WATCHOS_MINIMUM_OS_OPTION])

    # `minimum_os_version` (aliased here as _VISIONOS_MINIMUM_OS_OPTION) is
    # always overwritten with the active platform's package minimum so that
    # downstream actions like SwiftDeriveFiles see a consistent configuration.
    asserts.equals(env, "13.0", actual[_VISIONOS_MINIMUM_OS_OPTION])

    return unittest.end(env)

sets_active_platform_to_package_minimum_test = unittest.make(_sets_active_platform_to_package_minimum_test)

def _overrides_higher_importer_with_package_minimum_test(ctx):
    env = unittest.begin(ctx)

    settings = _settings("ios", ios = "18.0")
    actual = minimum_os_transition.transition_outputs(
        settings = settings,
        attr = _attrs(),
    )

    asserts.equals(env, "18.0", settings[_IOS_MINIMUM_OS_OPTION])
    asserts.equals(env, "13.0", actual[_IOS_MINIMUM_OS_OPTION])

    return unittest.end(env)

overrides_higher_importer_with_package_minimum_test = unittest.make(_overrides_higher_importer_with_package_minimum_test)

def _uses_package_minimum_when_importer_unset_test(ctx):
    env = unittest.begin(ctx)

    actual = minimum_os_transition.transition_outputs(
        settings = _settings("ios", ios = ""),
        attr = _attrs(),
    )

    asserts.equals(env, "13.0", actual[_IOS_MINIMUM_OS_OPTION])

    return unittest.end(env)

uses_package_minimum_when_importer_unset_test = unittest.make(_uses_package_minimum_when_importer_unset_test)

def _uses_minimum_os_version_for_visionos_test(ctx):
    env = unittest.begin(ctx)

    actual = minimum_os_transition.transition_outputs(
        settings = _settings("visionos"),
        attr = _attrs(),
    )

    asserts.equals(env, "1.0", actual[_VISIONOS_MINIMUM_OS_OPTION])

    return unittest.end(env)

uses_minimum_os_version_for_visionos_test = unittest.make(_uses_minimum_os_version_for_visionos_test)

def _preserves_settings_for_non_apple_platform_test(ctx):
    env = unittest.begin(ctx)

    actual = minimum_os_transition.transition_outputs(
        settings = _settings("linux"),
        attr = _attrs(),
    )

    asserts.equals(env, {
        _IOS_MINIMUM_OS_OPTION: "18.0",
        _MACOS_MINIMUM_OS_OPTION: "15.0",
        _TVOS_MINIMUM_OS_OPTION: "18.0",
        _WATCHOS_MINIMUM_OS_OPTION: "11.0",
        _VISIONOS_MINIMUM_OS_OPTION: "2.0",
    }, actual)

    return unittest.end(env)

preserves_settings_for_non_apple_platform_test = unittest.make(_preserves_settings_for_non_apple_platform_test)

def _rejects_imported_target_with_higher_minimum_os_test(ctx):
    env = unittest.begin(ctx)

    error = minimum_os_transition.import_error(
        target_name = "PackageB.rspm",
        platform_type = "ios",
        importer_minimum_os = "13.0",
        imported_minimum_os = "16.0",
    )

    asserts.equals(
        env,
        "The target 'PackageB.rspm' requires ios 16.0, but is being imported from a target configured for ios 13.0; consider raising the importing target's minimum OS to 16.0 or later.",
        error,
    )

    return unittest.end(env)

rejects_imported_target_with_higher_minimum_os_test = unittest.make(_rejects_imported_target_with_higher_minimum_os_test)

def _allows_imported_target_with_equal_or_lower_minimum_os_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        None,
        minimum_os_transition.import_error(
            target_name = "PackageB.rspm",
            platform_type = "ios",
            importer_minimum_os = "13.0",
            imported_minimum_os = "13.0",
        ),
    )
    asserts.equals(
        env,
        None,
        minimum_os_transition.import_error(
            target_name = "PackageB.rspm",
            platform_type = "ios",
            importer_minimum_os = "13.0",
            imported_minimum_os = "12.0",
        ),
    )

    return unittest.end(env)

allows_imported_target_with_equal_or_lower_minimum_os_test = unittest.make(_allows_imported_target_with_equal_or_lower_minimum_os_test)

def _rejects_imported_target_with_higher_patch_minimum_os_test(ctx):
    env = unittest.begin(ctx)

    error = minimum_os_transition.import_error(
        target_name = "PackageB.rspm",
        platform_type = "ios",
        importer_minimum_os = "13.0.1",
        imported_minimum_os = "13.0.2",
    )

    asserts.equals(
        env,
        "The target 'PackageB.rspm' requires ios 13.0.2, but is being imported from a target configured for ios 13.0.1; consider raising the importing target's minimum OS to 13.0.2 or later.",
        error,
    )

    return unittest.end(env)

rejects_imported_target_with_higher_patch_minimum_os_test = unittest.make(_rejects_imported_target_with_higher_patch_minimum_os_test)

def minimum_os_transition_test_suite():
    return unittest.suite(
        "minimum_os_transition_tests",
        sets_active_platform_to_package_minimum_test,
        overrides_higher_importer_with_package_minimum_test,
        uses_package_minimum_when_importer_unset_test,
        uses_minimum_os_version_for_visionos_test,
        preserves_settings_for_non_apple_platform_test,
        rejects_imported_target_with_higher_minimum_os_test,
        allows_imported_target_with_equal_or_lower_minimum_os_test,
        rejects_imported_target_with_higher_patch_minimum_os_test,
    )
