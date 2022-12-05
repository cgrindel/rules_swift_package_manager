"""Tests for `pkginfo_targets`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:package_infos.bzl", "module_types", "package_infos", "target_types")
load("//swiftpkg/internal:pkginfo_targets.bzl", "pkginfo_targets")

_foo_target = package_infos.new_target(
    name = "Foo",
    type = target_types.library,
    c99name = "Foo",
    module_type = module_types.swift,
    path = "Sources/Foo",
    sources = ["Chicken.swift", "Chicken+Extensions.swift"],
    dependencies = [],
)

def _srcs_test(ctx):
    env = unittest.begin(ctx)

    actual = pkginfo_targets.srcs(_foo_target)
    expected = [
        "Sources/Foo/Chicken.swift",
        "Sources/Foo/Chicken+Extensions.swift",
    ]
    asserts.equals(env, expected, actual)

    return unittest.end(env)

srcs_test = unittest.make(_srcs_test)

def _deps_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

deps_test = unittest.make(_deps_test)

def pkginfo_targets_test_suite():
    return unittest.suite(
        "pkginfo_targets_tests",
        srcs_test,
        deps_test,
    )
