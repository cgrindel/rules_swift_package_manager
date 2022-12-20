"""Tests for `bazel_repo_names` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:bazel_repo_names.bzl", "bazel_repo_names")

def _from_identity_test(ctx):
    env = unittest.begin(ctx)

    test_data = [
        ("SwiftFormat", "@swiftpkg_SwiftFormat"),
        ("swift-argument-parser", "@swiftpkg_swift_argument_parser"),
    ]
    for (identity, expected) in test_data:
        actual = bazel_repo_names.from_identity(identity)
        asserts.equals(env, expected, actual)

    return unittest.end(env)

from_identity_test = unittest.make(_from_identity_test)

def _normalize_test(ctx):
    env = unittest.begin(ctx)

    actual = bazel_repo_names.normalize("@swiftpkg_swift_argument_parser")
    asserts.equals(env, "@swiftpkg_swift_argument_parser", actual)

    actual = bazel_repo_names.normalize("swiftpkg_swift_argument_parser")
    asserts.equals(env, "@swiftpkg_swift_argument_parser", actual)

    return unittest.end(env)

normalize_test = unittest.make(_normalize_test)

def bazel_repo_names_test_suite():
    return unittest.suite(
        "bazel_repo_names_tests",
        from_identity_test,
        normalize_test,
    )
