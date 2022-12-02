"""Tests for `starlark_utils` API"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:starlark_utils.bzl", "starlark_utils")

def _indent_str_test(ctx):
    env = unittest.begin(ctx)

    actual = starlark_utils.indent(0)
    asserts.equals(env, "", actual)

    actual = starlark_utils.indent(1)
    asserts.equals(env, "    ", actual)

    actual = starlark_utils.indent(2)
    asserts.equals(env, "        ", actual)

    actual = starlark_utils.indent(0, "foo")
    asserts.equals(env, "foo", actual)

    actual = starlark_utils.indent(1, "foo")
    asserts.equals(env, "    foo", actual)

    return unittest.end(env)

indent_str_test = unittest.make(_indent_str_test)

def _quote_test(ctx):
    env = unittest.begin(ctx)

    actual = starlark_utils.quote("")
    asserts.equals(env, "\"\"", actual)

    actual = starlark_utils.quote("hello")
    asserts.equals(env, "\"hello\"", actual)

    return unittest.end(env)

quote_test = unittest.make(_quote_test)

def _list_to_str_test(ctx):
    env = unittest.begin(ctx)

    actual = starlark_utils.list_to_str([])
    expected = ""
    asserts.equals(env, expected, actual, "no values")

    values = ["apple", "pear", "cherries"]

    actual = starlark_utils.list_to_str(values, double_quote_values = False)
    expected = """\
        apple,
        pear,
        cherries,\
"""
    asserts.equals(env, expected, actual, "values, no double quote")

    actual = starlark_utils.list_to_str(values)
    expected = """\
        "apple",
        "pear",
        "cherries",\
"""
    asserts.equals(env, expected, actual, "values, double quote")

    actual = starlark_utils.list_to_str(values, indent = "")
    expected = """\
"apple",
"pear",
"cherries",\
"""
    asserts.equals(env, expected, actual, "values, no double quote, no indent")

    return unittest.end(env)

list_to_str_test = unittest.make(_list_to_str_test)

def starlark_utils_test_suite():
    return unittest.suite(
        "starlark_utils_tests",
        indent_str_test,
        quote_test,
        list_to_str_test,
    )
