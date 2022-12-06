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

def _find_decl_test(ctx):
    env = unittest.begin(ctx)

    horse_decl = build_decls.new("smidgen_library", "horse")

    build_file = build_files.new(
        load_stmts = [
            load_statements.new("@chicken//:defs.bzl", "chicken_binary", "chicken_library"),
            load_statements.new("@smidgen//:defs.bzl", "smidgen_library"),
        ],
        decls = [
            build_decls.new("chicken_binary", "goodbye"),
            build_decls.new("chicken_library", "hello"),
            horse_decl,
        ],
    )

    actual = build_files.find_decl(build_file, "does_not_exist", fail_if_not_found = False)
    asserts.equals(env, None, actual)

    actual = build_files.find_decl(build_file, "horse", fail_if_not_found = False)
    asserts.equals(env, horse_decl, actual)

    return unittest.end(env)

find_decl_test = unittest.make(_find_decl_test)

def build_files_test_suite():
    return unittest.suite(
        "build_files_tests",
        merge_test,
        find_decl_test,
    )
