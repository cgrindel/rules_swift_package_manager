"""Tests for spm_versions module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//spm:defs.bzl", "spm_versions")

def _extract_test(ctx):
    env = unittest.begin(ctx)

    raw_str = "Swift Package Manager - Swift 5.4.0"
    actual = spm_versions.extract(raw_str)
    asserts.equals(env, "5.4.0", actual)

    return unittest.end(env)

extract_test = unittest.make(_extract_test)

def spm_versions_test_suite():
    return unittest.suite(
        "spm_versions_tests",
        extract_test,
    )
