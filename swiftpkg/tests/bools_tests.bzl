"""Tests for `bools` API"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:bools.bzl", "bools")

def _to_shell_str_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, "true", bools.to_shell_str(True))
    asserts.equals(env, "false", bools.to_shell_str(False))

    # Non-bool truthiness falls through the same branch that Starlark
    # uses for `if value`: non-empty containers and non-zero numbers
    # serialize as "true"; empty / zero / None serialize as "false".
    asserts.equals(env, "true", bools.to_shell_str(1))
    asserts.equals(env, "false", bools.to_shell_str(0))
    asserts.equals(env, "true", bools.to_shell_str("x"))
    asserts.equals(env, "false", bools.to_shell_str(""))
    asserts.equals(env, "false", bools.to_shell_str(None))
    asserts.equals(env, "true", bools.to_shell_str([1]))
    asserts.equals(env, "false", bools.to_shell_str([]))

    return unittest.end(env)

to_shell_str_test = unittest.make(_to_shell_str_test)

def bools_test_suite():
    return unittest.suite(
        "bools_tests",
        to_shell_str_test,
    )
