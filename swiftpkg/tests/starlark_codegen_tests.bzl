"""Tests for `starlark_codegen` API"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:starlark_codegen.bzl", scg = "starlark_codegen")

def _indent_str_test(ctx):
    env = unittest.begin(ctx)

    actual = scg.indent(0)
    asserts.equals(env, "", actual)

    actual = scg.indent(1)
    asserts.equals(env, "    ", actual)

    actual = scg.indent(2)
    asserts.equals(env, "        ", actual)

    actual = scg.indent(0, "foo")
    asserts.equals(env, "foo", actual)

    actual = scg.indent(1, "foo")
    asserts.equals(env, "    foo", actual)

    return unittest.end(env)

indent_str_test = unittest.make(_indent_str_test)

def _to_starlark_test(ctx):
    env = unittest.begin(ctx)

    actual = scg.to_starlark("hello")
    expected = '"hello"'
    asserts.equals(env, expected, actual)

    actual = scg.to_starlark(True)
    expected = "True"
    asserts.equals(env, expected, actual)

    actual = scg.to_starlark(123)
    expected = "123"
    asserts.equals(env, expected, actual)

    actual = scg.to_starlark([])
    expected = "[]"
    asserts.equals(env, expected, actual)

    actual = scg.to_starlark(["hello", 123, "goodbye"])
    expected = """\
[
    "hello",
    123,
    "goodbye",
]\
"""
    asserts.equals(env, expected, actual)

    actual = scg.to_starlark({})
    expected = "{}"
    asserts.equals(env, expected, actual)

    actual = scg.to_starlark({
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

    actual = scg.to_starlark([["hello"], [123, "goodbye"], {"chicken": "smidgen"}])
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

def _custom_struct(name, kind):
    return struct(
        name = name,
        kind = kind,
        to_starlark_parts = _custom_to_starlark_parts,
    )

def _custom_to_starlark_parts(val, indent):
    output = ["{}(\n".format(val.kind)]
    output.extend(scg.attr("name", val.name, indent + 1))
    output.append(scg.indent(indent, ")"))
    return output

def _to_starlark_with_struct_test(ctx):
    env = unittest.begin(ctx)

    my_struct = _custom_struct(kind = "chicken_binary", name = "say_hello")
    actual = scg.to_starlark(my_struct)
    expected = """\
chicken_binary(
    name = "say_hello",
)\
"""
    asserts.equals(env, expected, actual)

    return unittest.end(env)

to_starlark_with_struct_test = unittest.make(_to_starlark_with_struct_test)

def starlark_codegen_test_suite():
    return unittest.suite(
        "starlark_codegen_tests",
        indent_str_test,
        to_starlark_test,
        to_starlark_with_struct_test,
    )
