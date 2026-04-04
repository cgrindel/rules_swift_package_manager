"""Tests for `pkginfos` SwiftPM argument generation."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos_testing")

def _manifest_swiftc_args_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        ["-Xbuild-tools-swiftc", "-DBAZEL"],
        pkginfos_testing.manifest_swiftc_args(),
    )

    return unittest.end(env)

manifest_swiftc_args_test = unittest.make(_manifest_swiftc_args_test)

def _dump_package_args_test(ctx):
    env = unittest.begin(ctx)

    actual = pkginfos_testing.dump_package_args(
        registries_directory = "/tmp/registries",
        replace_scm_with_registry = True,
    )

    asserts.equals(
        env,
        [
            "swift",
            "package",
            "-Xbuild-tools-swiftc",
            "-DBAZEL",
            "--config-path",
            "/tmp/registries",
            "--replace-scm-with-registry",
            "dump-package",
        ],
        actual,
    )

    return unittest.end(env)

dump_package_args_test = unittest.make(_dump_package_args_test)

def _describe_package_args_test(ctx):
    env = unittest.begin(ctx)

    actual = pkginfos_testing.describe_package_args()

    asserts.equals(
        env,
        [
            "swift",
            "package",
            "-Xbuild-tools-swiftc",
            "-DBAZEL",
            "describe",
            "--type",
            "json",
        ],
        actual,
    )

    return unittest.end(env)

describe_package_args_test = unittest.make(_describe_package_args_test)

def pkginfos_command_args_test_suite():
    return unittest.suite(
        "pkginfos_command_args_tests",
        manifest_swiftc_args_test,
        dump_package_args_test,
        describe_package_args_test,
    )
