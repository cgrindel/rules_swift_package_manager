"""Tests for `pkginfo_targets`."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")

def _srcs_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

srcs_test = unittest.make(_srcs_test)

def pkginfo_targets_test_suite():
    return unittest.suite(
        "pkginfo_targets_tests",
        srcs_test,
    )
