"""Tests for collect umbrella directory declaration."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")
load("//swiftpkg/internal/modulemap_parser:declarations.bzl", "declarations")
load(":test_helpers.bzl", "do_parse_test")

def _parse_test(ctx):
    env = unittest.begin(ctx)

    do_parse_test(
        env,
        "module with umbrella dir",
        text = """
        module MyModule {
            umbrella "path/to/header/files"
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.umbrella_directory("path/to/header/files"),
                ],
            ),
        ],
    )

    return unittest.end(env)

parse_test = unittest.make(_parse_test)

def collect_umbrella_dir_declaration_test_suite():
    return unittest.suite(
        "collect_umbrella_dir_declaration_tests",
        parse_test,
    )
