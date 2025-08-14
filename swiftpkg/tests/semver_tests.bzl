"""Tests for `semver` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:semver.bzl", "semver")

def _major_minor_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, semver.major_minor("5"), (5, 0))
    asserts.equals(env, semver.major_minor("5.x"), (5, 0))
    asserts.equals(env, semver.major_minor("5.9"), (5, 9))
    asserts.equals(env, semver.major_minor("5.10"), (5, 10))
    asserts.equals(env, semver.major_minor("6.1"), (6, 1))

    return unittest.end(env)

major_minor_test = unittest.make(_major_minor_test)

def semver_test_suite():
    return unittest.suite(
        "semver_tests",
        major_minor_test,
    )
