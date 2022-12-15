"""Tests for `bazel_repo_names` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:bazel_repo_names.bzl", "bazel_repo_names")

def _from_url_test(ctx):
    env = unittest.begin(ctx)

    test_data = [
        ("https://github.com/nicklockwood/SwiftFormat.git", "@nicklockwood_SwiftFormat"),
        ("http://github.com/nicklockwood/SwiftFormat", "@nicklockwood_SwiftFormat"),
        ("https://github.com/apple/swift-argument-parser", "@apple_swift_argument_parser"),
    ]
    for (url, expected) in test_data:
        actual = bazel_repo_names.from_url(url)
        asserts.equals(env, expected, actual)

    return unittest.end(env)

from_url_test = unittest.make(_from_url_test)

def _normalize_test(ctx):
    env = unittest.begin(ctx)

    actual = bazel_repo_names.normalize("@apple_swift_argument_parser")
    asserts.equals(env, "@apple_swift_argument_parser", actual)

    actual = bazel_repo_names.normalize("apple_swift_argument_parser")
    asserts.equals(env, "@apple_swift_argument_parser", actual)

    return unittest.end(env)

normalize_test = unittest.make(_normalize_test)

def bazel_repo_names_test_suite():
    return unittest.suite(
        "bazel_repo_names_tests",
        from_url_test,
        normalize_test,
    )
