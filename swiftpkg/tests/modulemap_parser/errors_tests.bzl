"""Tests for errors module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal/modulemap_parser:errors.bzl", "errors")

def _create_test(ctx):
    env = unittest.begin(ctx)

    result = errors.new(
        msg = "The message",
        child_errors = ["child_error"],
    )
    expected = struct(
        msg = "The message",
        child_errors = ["child_error"],
    )
    asserts.equals(env, expected, result)

    return unittest.end(env)

create_test = unittest.make(_create_test)

def errors_test_suite():
    return unittest.suite(
        "errors_tests",
        create_test,
    )
