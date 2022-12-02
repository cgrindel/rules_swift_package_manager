"""Tests for collect_export_declaration module."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")
load("//swiftpkg/internal/modulemap_parser:declarations.bzl", "declarations")
load(":test_helpers.bzl", "do_parse_test")

def _collect_export_declaration_test(ctx):
    env = unittest.begin(ctx)

    do_parse_test(
        env,
        "module with wildcard export",
        text = """
        module MyModule {
            export *
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.export(wildcard = True),
                ],
            ),
        ],
    )

    do_parse_test(
        env,
        "module with export identifiers",
        text = """
        module MyModule {
            export foo.bar
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.export(identifiers = ["foo", "bar"]),
                ],
            ),
        ],
    )

    do_parse_test(
        env,
        "module with export identifiers",
        text = """
        module MyModule {
            export foo.bar.*
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.export(identifiers = ["foo", "bar"], wildcard = True),
                ],
            ),
        ],
    )

    return unittest.end(env)

collect_export_declaration_test = unittest.make(_collect_export_declaration_test)

def collect_export_declaration_test_suite():
    return unittest.suite(
        "collect_export_declaration_tests",
        collect_export_declaration_test,
    )
