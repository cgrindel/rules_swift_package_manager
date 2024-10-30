"""Tests for collect_module."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")
load("//swiftpkg/internal/modulemap_parser:declarations.bzl", "declarations")
load("//swiftpkg/internal/modulemap_parser:tokens.bzl", "tokens")
load(":test_helpers.bzl", "do_failing_parse_test", "do_parse_test")

def _collect_module_test(ctx):
    env = unittest.begin(ctx)

    do_parse_test(
        env,
        "module without qualifiers, attributes and members",
        text = """
        module MyModule {}
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

    do_parse_test(
        env,
        "module with members",
        text = """
        module MyModule {
            header "SomeHeader.h"
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                framework = False,
                explicit = False,
                attributes = [],
                members = [
                    struct(attribs = None, decl_type = "single_header", path = "SomeHeader.h", private = False, textual = False),
                ],
            ),
        ],
    )

    do_parse_test(
        env,
        "module with umbrella header declaration",
        text = """
        module "MyModule" {
            umbrella header "MyModule/MyModule.h"
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                framework = False,
                explicit = False,
                attributes = [],
                members = [
                    struct(attribs = None, decl_type = "umbrella_header", path = "MyModule/MyModule.h", private = False, textual = False),
                ],
            ),
        ],

    )

    do_parse_test(
        env,
        "two modules with members and exports with newlines",
        text = """
        module MyModule {
            header "SomeHeader.h"
            header "SomeOtherHeader.h"
            export *
        }

        module MyModuleTwo {
            header "SecondHeader.h"
            header "ThirdHeader.h"
            export *
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                framework = False,
                explicit = False,
                attributes = [],
                members = [
                    struct(attribs = None, decl_type = "single_header", path = "SomeHeader.h", private = False, textual = False),
                    struct(attribs = None, decl_type = "single_header", path = "SomeOtherHeader.h", private = False, textual = False),
                    struct(decl_type = "export", identifiers = [], wildcard = True),
                ],
            ),
            declarations.module(
                module_id = "MyModuleTwo",
                framework = False,
                explicit = False,
                attributes = [],
                members = [
                    struct(attribs = None, decl_type = "single_header", path = "SecondHeader.h", private = False, textual = False),
                    struct(attribs = None, decl_type = "single_header", path = "ThirdHeader.h", private = False, textual = False),
                    struct(decl_type = "export", identifiers = [], wildcard = True),
                ],
            ),
        ],
    )

    do_parse_test(
        env,
        "module with qualifiers",
        text = """
        framework module MyModule {}
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                framework = True,
                explicit = False,
                attributes = [],
                members = [],
            ),
        ],
    )

    do_parse_test(
        env,
        "module with asterisk module",
        text = """
        framework module MyModule {
            module * { export * }
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                framework = True,
                explicit = False,
                attributes = [],
                members = [declarations.module("*", members = [
                    declarations.export(wildcard = True),
                ])],
            ),
        ],
    )

    do_parse_test(
        env,
        "module with attributes",
        text = """
        module MyModule [system] [extern_c] {}
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                framework = False,
                explicit = False,
                attributes = ["system", "extern_c"],
                members = [],
            ),
        ],
    )

    do_failing_parse_test(
        env,
        "module with unexpected qualifier",
        text = """
        unexpected module MyModule {}
        """,
        expected_err = "Unexpected prefix token collecting module declaration. token: %s" %
                       (tokens.identifier("unexpected")),
    )

    do_failing_parse_test(
        env,
        "module with missing module id",
        text = """
        module {}
        """,
        expected_err = "Expected module identifier or asterisk, but was curly_bracket_open.",
    )

    do_failing_parse_test(
        env,
        "module with malformed attribute",
        text = """
        module MyModule [system {}
        """,
        expected_err = "Expected type square_bracket_close, but was curly_bracket_open",
    )

    return unittest.end(env)

collect_module_test = unittest.make(_collect_module_test)

def _parse_submodule_in_module_test(ctx):
    env = unittest.begin(ctx)

    do_parse_test(
        env,
        "module with submodules",
        text = """
        module MyModule {
            module MySubmodule {
                module AnotherSubmodule {}
            }
        }
        """,
        expected = [
            declarations.module(
                module_id = "MyModule",
                members = [
                    declarations.module(
                        module_id = "MySubmodule",
                        members = [
                            declarations.module("AnotherSubmodule"),
                        ],
                    ),
                ],
            ),
        ],
    )

    return unittest.end(env)

parse_submodule_in_module_test = unittest.make(_parse_submodule_in_module_test)

def collect_module_test_suite():
    return unittest.suite(
        "collect_module_tests",
        collect_module_test,
        parse_submodule_in_module_test,
    )
