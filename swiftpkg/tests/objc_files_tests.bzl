"""Tests for `objc_files` module."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")

def _parse_pound_import_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

parse_pound_import_test = unittest.make(_parse_pound_import_test)

def _parse_at_import_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

parse_at_import_test = unittest.make(_parse_at_import_test)

def objc_files_test_suite():
    return unittest.suite(
        "objc_files_tests",
        parse_pound_import_test,
        parse_at_import_test,
    )
