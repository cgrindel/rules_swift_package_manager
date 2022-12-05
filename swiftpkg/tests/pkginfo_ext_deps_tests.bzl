"""Tests for `pkginfo_ext_deps` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:package_infos.bzl", "package_infos")
load("//swiftpkg/internal:pkginfo_ext_deps.bzl", "pkginfo_ext_deps")

_swift_arg_parser = package_infos.new_dependency(
    identity = "swift-argument-parser",
    type = "sourceControl",
    url = "https://github.com/apple/swift-argument-parser",
    requirement = package_infos.new_dependency_requirement(
        ranges = [
            package_infos.new_version_range(
                lower = "1.2.0",
                upper = "2.0.0",
            ),
        ],
    ),
)

_super_cool_pkg = package_infos.new_dependency(
    identity = "super-cool-package",
    type = "sourceControl",
    url = "https://github.com/example/super-cool-package",
    requirement = package_infos.new_dependency_requirement(
        ranges = [
            package_infos.new_version_range(
                lower = "0.0.0",
                upper = "1.0.0",
            ),
        ],
    ),
)

_ext_deps = [_swift_arg_parser, _super_cool_pkg]

def _find_by_identity_test(ctx):
    env = unittest.begin(ctx)

    actual = pkginfo_ext_deps.find_by_identity(
        [],
        "does-not-exit",
        fail_if_not_found = False,
    )
    asserts.equals(env, None, actual)

    actual = pkginfo_ext_deps.find_by_identity(
        _ext_deps,
        "does-not-exit",
        fail_if_not_found = False,
    )
    asserts.equals(env, None, actual)

    actual = pkginfo_ext_deps.find_by_identity(
        _ext_deps,
        "super-cool-package",
        fail_if_not_found = False,
    )
    asserts.equals(env, _super_cool_pkg, actual)

    return unittest.end(env)

find_by_identity_test = unittest.make(_find_by_identity_test)

def pkginfo_ext_deps_test_suite():
    return unittest.suite(
        "pkginfo_ext_deps_tests",
        find_by_identity_test,
    )
