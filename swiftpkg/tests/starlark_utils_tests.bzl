"""Tests for `starlark_utils` API"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:starlark_utils.bzl", su = "starlark_utils")

def _indent_str_test(ctx):
    env = unittest.begin(ctx)

    actual = su.indent(0)
    asserts.equals(env, "", actual)

    actual = su.indent(1)
    asserts.equals(env, "    ", actual)

    actual = su.indent(2)
    asserts.equals(env, "        ", actual)

    actual = su.indent(0, "foo")
    asserts.equals(env, "foo", actual)

    actual = su.indent(1, "foo")
    asserts.equals(env, "    foo", actual)

    return unittest.end(env)

indent_str_test = unittest.make(_indent_str_test)

def _to_starlark_test(ctx):
    env = unittest.begin(ctx)

    actual = su.to_starlark("hello")
    expected = '"hello"'
    asserts.equals(env, expected, actual)

    actual = su.to_starlark(True)
    expected = "True"
    asserts.equals(env, expected, actual)

    actual = su.to_starlark(123)
    expected = "123"
    asserts.equals(env, expected, actual)

    actual = su.to_starlark([])
    expected = "[]"
    asserts.equals(env, expected, actual)

    actual = su.to_starlark(["hello", 123, "goodbye"])
    expected = """\
[
    "hello",
    123,
    "goodbye",
]\
"""
    asserts.equals(env, expected, actual)

    actual = su.to_starlark({})
    expected = "{}"
    asserts.equals(env, expected, actual)

    actual = su.to_starlark({
        "goodbye": True,
        "hello": 123,
    })
    expected = """\
{
    "goodbye": True,
    "hello": 123,
}\
"""
    asserts.equals(env, expected, actual)

    actual = su.to_starlark([["hello"], [123, "goodbye"], {"chicken": "smidgen"}])
    expected = """\
[
    [
        "hello",
    ],
    [
        123,
        "goodbye",
    ],
    {
        "chicken": "smidgen",
    },
]\
"""
    asserts.equals(env, expected, actual)

    return unittest.end(env)

to_starlark_test = unittest.make(_to_starlark_test)

def starlark_utils_test_suite():
    return unittest.suite(
        "starlark_utils_tests",
        indent_str_test,
        to_starlark_test,
    )
