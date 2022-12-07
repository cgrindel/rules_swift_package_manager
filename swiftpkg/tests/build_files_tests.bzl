"""Tests for `build_files` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:build_files.bzl", "build_files")
load("//swiftpkg/internal:load_statements.bzl", "load_statements")

def _merge_test(ctx):
    env = unittest.begin(ctx)

    bfiles = [
        build_files.new(
            load_stmts = [load_statements.new("@chicken//:defs.bzl", "chicken_library")],
            decls = [build_decls.new("chicken_library", "hello")],
        ),
        build_files.new(
            load_stmts = [load_statements.new("@chicken//:defs.bzl", "chicken_binary")],
            decls = [build_decls.new("chicken_binary", "goodbye")],
        ),
        build_files.new(
            load_stmts = [load_statements.new("@smidgen//:defs.bzl", "smidgen_library")],
            decls = [build_decls.new("smidgen_library", "horse")],
        ),
    ]
    actual = build_files.merge(*bfiles)
    expected = build_files.new(
        load_stmts = [
            load_statements.new("@chicken//:defs.bzl", "chicken_binary", "chicken_library"),
            load_statements.new("@smidgen//:defs.bzl", "smidgen_library"),
        ],
        decls = [
            build_decls.new("chicken_binary", "goodbye"),
            build_decls.new("chicken_library", "hello"),
            build_decls.new("smidgen_library", "horse"),
        ],
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

merge_test = unittest.make(_merge_test)

def build_files_test_suite():
    return unittest.suite(
        "build_files_tests",
        merge_test,
    )
