"""Tests for collect_header_declaration."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")
load("//swiftpkg/internal/modulemap_parser:declarations.bzl", "declarations")
load(":test_helpers.bzl", "do_parse_test")

def _parse_single_header_test(ctx):
    env = unittest.begin(ctx)

    do_parse_test(
        env,
        "module with single header, no qualifiers",
        text = """
        module MyModule {
            header "path/to/header.h"
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.single_header("path/to/header.h"),
                ],
            ),
        ],
    )

    do_parse_test(
        env,
        "module with single header and attributes (ignored)",
        text = """
        module MyModule {
            header "path/to/header.h" {
                size 1234
                mtime 5678
            }
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.single_header("path/to/header.h"),
                ],
            ),
        ],
    )

    do_parse_test(
        env,
        "module with single header, as private",
        text = """
        module MyModule {
            private header "path/to/header.h"
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.single_header("path/to/header.h", private = True),
                ],
            ),
        ],
    )

    do_parse_test(
        env,
        "module with single header, as textual",
        text = """
        module MyModule {
            textual header "path/to/header.h"
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.single_header("path/to/header.h", textual = True),
                ],
            ),
        ],
    )

    return unittest.end(env)

parse_single_header_test = unittest.make(_parse_single_header_test)

def _parse_umbrella_header_test(ctx):
    env = unittest.begin(ctx)

    do_parse_test(
        env,
        "module with umbrella header",
        text = """
        module MyModule {
            umbrella header "path/to/header.h"
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.umbrella_header("path/to/header.h"),
                ],
            ),
        ],
    )

    return unittest.end(env)

parse_umbrella_header_test = unittest.make(_parse_umbrella_header_test)

def _parse_exclude_header_test(ctx):
    env = unittest.begin(ctx)

    do_parse_test(
        env,
        "module with exclude header",
        text = """
        module MyModule {
            exclude header "path/to/header.h"
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.exclude_header("path/to/header.h"),
                ],
            ),
        ],
    )

    return unittest.end(env)

parse_exclude_header_test = unittest.make(_parse_exclude_header_test)

def collect_header_declaration_test_suite():
    return unittest.suite(
        "collect_header_declaration_tests",
        parse_single_header_test,
        parse_umbrella_header_test,
        parse_exclude_header_test,
    )
