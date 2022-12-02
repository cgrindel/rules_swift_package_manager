"""Tests for collect_link_declaration."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")
load("//swiftpkg/internal/modulemap_parser:declarations.bzl", "declarations")
load(":test_helpers.bzl", "do_parse_test")

def _collect_link_declaration_test(ctx):
    env = unittest.begin(ctx)

    do_parse_test(
        env,
        "module with library link",
        text = """
        module MyModule {
            link "sqlite3"
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.link("sqlite3"),
                ],
            ),
        ],
    )

    do_parse_test(
        env,
        "module with framework link",
        text = """
        module MyModule {
            link framework "MyFramework"
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.link("MyFramework", framework = True),
                ],
            ),
        ],
    )

    return unittest.end(env)

collect_link_declaration_test = unittest.make(_collect_link_declaration_test)

def collect_link_declaration_test_suite():
    return unittest.suite(
        "collect_link_declaration_tests",
        collect_link_declaration_test,
    )
