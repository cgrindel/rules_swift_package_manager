"""Tests for `starlark_utils` API"""

load("@bazel_skylib//lib:unittest.bzl", "unittest")

def _quote_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

quote_test = unittest.make(_quote_test)

def _list_to_str_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

list_to_str_test = unittest.make(_list_to_str_test)

def starlark_utils_test_suite():
    return unittest.suite(
        "starlark_utils_tests",
        quote_test,
        list_to_str_test,
    )
