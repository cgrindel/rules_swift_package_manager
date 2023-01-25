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
    ["hello"],
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

def _custom_struct(name, kind, values = {}):
    return struct(
        name = name,
        kind = kind,
        values = values,
        to_starlark_parts = _custom_to_starlark_parts,
    )

def _custom_to_starlark_parts(val, indent):
    child_indent = indent + 1
    output = ["{}(\n".format(val.kind)]
    output.extend(scg.new_attr("name", val.name, child_indent))
    if len(val.values) > 0:
        output.extend(scg.new_attr("values", val.values, child_indent))
    output.append(scg.indent(indent, ")"))
    return output

def _to_starlark_with_struct_test(ctx):
    env = unittest.begin(ctx)

    my_struct = _custom_struct(
        kind = "chicken_binary",
        name = "say_hello",
        values = {
            "bar": _custom_struct("goodbye", "chicken_library"),
            "foo": "hello",
        },
    )
    actual = scg.to_starlark(my_struct)
    expected = """\
chicken_binary(
    name = "say_hello",
    values = {
        "bar": chicken_library(
            name = "goodbye",
        ),
        "foo": "hello",
    },
)\
"""
    asserts.equals(env, expected, actual)

    return unittest.end(env)

to_starlark_with_struct_test = unittest.make(_to_starlark_with_struct_test)

def _fn_call_to_starlark_parts_test(ctx):
    env = unittest.begin(ctx)

    fn_call = scg.new_fn_call("foo")
    expected = "foo()"
    code = scg.to_starlark(fn_call)
    asserts.equals(env, expected, code)

    fn_call = scg.new_fn_call("foo", "first")
    expected = """\
foo("first")\
"""
    code = scg.to_starlark(fn_call)
    asserts.equals(env, expected, code)

    fn_call = scg.new_fn_call("foo", ["item0"])
    expected = """\
foo(["item0"])\
"""
    code = scg.to_starlark(fn_call)
    asserts.equals(env, expected, code)

    fn_call = scg.new_fn_call("foo", ["item0", "item1"])
    expected = """\
foo([
    "item0",
    "item1",
])\
"""
    code = scg.to_starlark(fn_call)
    asserts.equals(env, expected, code)

    fn_call = scg.new_fn_call("foo", 123, 456)
    expected = """\
foo(
    123,
    456,
)\
"""
    code = scg.to_starlark(fn_call)
    asserts.equals(env, expected, code)

    fn_call = scg.new_fn_call(
        "foo",
        zebra = "goodbye",
        bar = "hello",
    )
    expected = """\
foo(
    zebra = "goodbye",
    bar = "hello",
)\
"""
    code = scg.to_starlark(fn_call)
    asserts.equals(env, expected, code)

    fn_call = scg.new_fn_call(
        "foo",
        "chicken",
        zebra = "goodbye",
        bar = "hello",
    )
    expected = """\
foo(
    "chicken",
    zebra = "goodbye",
    bar = "hello",
)\
"""
    code = scg.to_starlark(fn_call)
    asserts.equals(env, expected, code)

    return unittest.end(env)

fn_call_to_starlark_parts_test = unittest.make(_fn_call_to_starlark_parts_test)

def _op_to_starlark_parts_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            op = scg.new_op("+"),
            exp = "+",
            msg = "plus",
        ),
    ]
    for t in tests:
        actual = scg.to_starlark(t.op)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

op_to_starlark_parts_test = unittest.make(_op_to_starlark_parts_test)

def _new_expr_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            expr = scg.new_expr("hello"),
            exp = ["hello"],
            msg = "a single part",
        ),
        struct(
            expr = scg.new_expr("hello", 123, ["howdy"]),
            exp = ["hello", 123, ["howdy"]],
            msg = "multiple parts",
        ),
    ]
    for t in tests:
        actual = t.expr.members
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

new_expr_test = unittest.make(_new_expr_test)

def _expr_to_starlark_parts_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            expr = scg.new_expr("hello"),
            exp = """\
"hello"\
""",
            msg = "a single part",
        ),
        struct(
            expr = scg.new_expr("hello", scg.new_op("+"), "goodbye"),
            exp = """\
"hello" + "goodbye"\
""",
            msg = "operator with two strings",
        ),
        struct(
            expr = scg.new_expr(
                ["hello", "goodbye"],
                scg.new_op("+"),
                scg.new_fn_call("glob", ["*"]),
            ),
            exp = """\
[
    "hello",
    "goodbye",
] + glob(["*"])\
""",
            msg = "operator with list and function call",
        ),
        struct(
            expr = scg.new_expr(
                ["hello", "goodbye"],
                scg.new_op("+"),
                ["chicken", "smidgen"],
            ),
            exp = """\
[
    "hello",
    "goodbye",
] + [
    "chicken",
    "smidgen",
]\
""",
            msg = "operator with list and function call",
        ),
    ]
    for t in tests:
        actual = scg.to_starlark(t.expr)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

expr_to_starlark_parts_test = unittest.make(_expr_to_starlark_parts_test)

def starlark_codegen_test_suite():
    return unittest.suite(
        "starlark_codegen_tests",
        indent_str_test,
        to_starlark_test,
        to_starlark_with_struct_test,
        fn_call_to_starlark_parts_test,
        op_to_starlark_parts_test,
        new_expr_test,
        expr_to_starlark_parts_test,
    )
