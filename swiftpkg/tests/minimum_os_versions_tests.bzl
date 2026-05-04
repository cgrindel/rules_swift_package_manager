"""Tests for package minimum OS version helpers."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:minimum_os_versions.bzl", "minimum_os_versions")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")

def _pkg_info(platforms = []):
    return struct(platforms = platforms)

def _transition_attrs_uses_declared_versions_test(ctx):
    env = unittest.begin(ctx)

    attrs = minimum_os_versions.transition_attrs(_pkg_info(platforms = [
        pkginfos.new_platform("iOS", "13.0"),
        pkginfos.new_platform("macOS", "10.15"),
        pkginfos.new_platform("tvOS", "13.0"),
        pkginfos.new_platform("visionOS", "1.0"),
        pkginfos.new_platform("watchOS", "6.0"),
    ]))

    asserts.equals(env, {
        "ios_minimum_os": "13.0",
        "macos_minimum_os": "10.15",
        "tvos_minimum_os": "13.0",
        "visionos_minimum_os": "1.0",
        "watchos_minimum_os": "6.0",
    }, attrs)

    return unittest.end(env)

transition_attrs_uses_declared_versions_test = unittest.make(_transition_attrs_uses_declared_versions_test)

def _transition_attrs_uses_fallbacks_for_omitted_platforms_test(ctx):
    env = unittest.begin(ctx)

    attrs = minimum_os_versions.transition_attrs(_pkg_info(platforms = [
        pkginfos.new_platform("iOS", "13.0"),
        pkginfos.new_platform("linux", "5.0"),
    ]))

    asserts.equals(env, {
        "ios_minimum_os": "13.0",
        "macos_minimum_os": "10.13",
        "tvos_minimum_os": "12.0",
        "visionos_minimum_os": "1.0",
        "watchos_minimum_os": "4.0",
    }, attrs)

    return unittest.end(env)

transition_attrs_uses_fallbacks_for_omitted_platforms_test = unittest.make(_transition_attrs_uses_fallbacks_for_omitted_platforms_test)

def _fallback_accepts_package_description_spelling_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, "1.0", minimum_os_versions.fallback("visionOS"))

    return unittest.end(env)

fallback_accepts_package_description_spelling_test = unittest.make(_fallback_accepts_package_description_spelling_test)

def minimum_os_versions_test_suite():
    return unittest.suite(
        "minimum_os_versions_tests",
        transition_attrs_uses_declared_versions_test,
        transition_attrs_uses_fallbacks_for_omitted_platforms_test,
        fallback_accepts_package_description_spelling_test,
    )
