"""Tests for collect_module_member."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")
load("//swiftpkg/internal/modulemap_parser:declarations.bzl", "declarations")
load(":test_helpers.bzl", "do_parse_test")

def _parse_newline_in_module_member_test(ctx):
    env = unittest.begin(ctx)

    do_parse_test(
        env,
        "module with newlines in members area",
        text = """
        module MyModule {

        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                framework = False,
                explicit = False,
                attributes = [],
                members = [],
            ),
        ],
    )

    return unittest.end(env)

parse_newline_in_module_member_test = unittest.make(_parse_newline_in_module_member_test)

def collect_module_member_test_suite():
    return unittest.suite(
        "collect_module_member_tests",
        parse_newline_in_module_member_test,
    )
