"""Tests for the swift_deps module extension helpers."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/bzlmod:swift_deps.bzl", "swift_deps_test_utils")

def _package_alias_ambiguity_test(ctx):
    env = unittest.begin(ctx)

    target_configs = [struct(
        condition = None,
        package = "SharedAlias",
        swift_copts = ["-DLOCAL"],
        target = "Library",
    )]
    matched_target_configs = {}
    available_target_config_packages = {}

    first_configs = swift_deps_test_utils.target_configs_for_dependency(
        struct(identity = "first-package", name = "SharedAlias"),
        target_configs,
        matched_target_configs,
        available_target_config_packages,
    )
    second_configs = swift_deps_test_utils.target_configs_for_dependency(
        struct(identity = "SharedAlias", name = "SecondPackage"),
        target_configs,
        matched_target_configs,
        available_target_config_packages,
    )
    ambiguities = swift_deps_test_utils.ambiguous_target_config_packages(
        target_configs,
        matched_target_configs,
    )

    asserts.equals(env, 1, len(first_configs))
    asserts.equals(env, 1, len(second_configs))
    asserts.equals(env, 1, len(ambiguities))
    asserts.equals(env, "SharedAlias", ambiguities[0].selector)
    asserts.equals(
        env,
        ["swiftpkg_SharedAlias", "swiftpkg_first_package"],
        ambiguities[0].matches,
    )

    return unittest.end(env)

package_alias_ambiguity_test = unittest.make(_package_alias_ambiguity_test)

def _unresolved_package_match_test(ctx):
    env = unittest.begin(ctx)

    target_configs = [struct(
        condition = None,
        package = "swift-log",
        swift_copts = ["-DLOCAL"],
        target = "Logging",
    )]
    matched_target_configs = {}
    available_target_config_packages = {}
    configs = swift_deps_test_utils.target_configs_for_dependency(
        # This dependency has no source-control pin, mirroring a dependency
        # missing from a stale Package.resolved. Matching must not depend on
        # resolution state.
        struct(identity = "swift-log", name = "swift-log"),
        target_configs,
        matched_target_configs,
        available_target_config_packages,
    )

    asserts.equals(env, 1, len(configs))
    asserts.equals(env, {"swiftpkg_swift_log": True}, matched_target_configs[0])
    asserts.true(env, "swift-log" in available_target_config_packages)

    return unittest.end(env)

unresolved_package_match_test = unittest.make(_unresolved_package_match_test)

def swift_deps_test_suite():
    return unittest.suite(
        "swift_deps_tests",
        package_alias_ambiguity_test,
        unresolved_package_match_test,
    )
