"""Tests for `pkginfo_test_deps`."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")

def _bzl_dep_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

bzl_dep_test = unittest.make(_bzl_dep_test)

def pkginfo_target_deps_test_suite():
    return unittest.suite(
        "pkginfo_target_deps_tests",
        bzl_dep_test,
    )
