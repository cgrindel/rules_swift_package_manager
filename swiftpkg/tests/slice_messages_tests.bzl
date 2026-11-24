"""Tests for `slice_messages` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:slice_messages.bzl", "slice_messages")

def _stale_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        "slice `swift/macos` (config `@platforms//os:macos`) is stale; " +
        "run `bazel run @swift_package//:cache` under flags that select " +
        "that config",
        slice_messages.stale("swift/macos", "@platforms//os:macos"),
    )

    return unittest.end(env)

stale_test = unittest.make(_stale_test)

def _missing_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        "package `swift-nio` is not in slice `swift/macos` " +
        "(config `@platforms//os:macos`); it is only available to the " +
        "other slices",
        slice_messages.missing(
            "swift/macos",
            "@platforms//os:macos",
            "swift-nio",
        ),
    )

    return unittest.end(env)

missing_test = unittest.make(_missing_test)

def _no_match_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        "No slice matches the current configuration; tried: //a, //b",
        slice_messages.no_match(["//b", "//a"]),
    )

    return unittest.end(env)

no_match_test = unittest.make(_no_match_test)

def slice_messages_test_suite():
    return unittest.suite(
        "slice_messages_tests",
        stale_test,
        missing_test,
        no_match_test,
    )
