"""Tests for `pkginfo_ext_deps` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:pkginfo_ext_deps.bzl", "pkginfo_ext_deps")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")

_swift_arg_parser = pkginfos.new_dependency(
    identity = "swift-argument-parser",
    type = "sourceControl",
    url = "https://github.com/apple/swift-argument-parser",
    requirement = pkginfos.new_dependency_requirement(
        ranges = [
            pkginfos.new_version_range(
                lower = "1.2.0",
                upper = "2.0.0",
            ),
        ],
    ),
)

_super_cool_pkg = pkginfos.new_dependency(
    identity = "super-cool-package",
    type = "sourceControl",
    url = "https://github.com/example/super-cool-package",
    requirement = pkginfos.new_dependency_requirement(
        ranges = [
            pkginfos.new_version_range(
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

def _bazel_repo_name_test(ctx):
    env = unittest.begin(ctx)

    actual = pkginfo_ext_deps.bazel_repo_name(_super_cool_pkg)
    asserts.equals(env, "swiftpkg_super_cool_package", actual)

    return unittest.end(env)

bazel_repo_name_test = unittest.make(_bazel_repo_name_test)

def pkginfo_ext_deps_test_suite():
    return unittest.suite(
        "pkginfo_ext_deps_tests",
        find_by_identity_test,
        bazel_repo_name_test,
    )
