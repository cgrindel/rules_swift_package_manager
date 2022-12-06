"""Tests for `build_files` module."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")

def build_files_test_suite():
    return unittest.suite(
        "build_files_tests",
        # TODO: Add tests here!
    )
