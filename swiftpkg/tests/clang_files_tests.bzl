"""Tests for clang_files."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:clang_files.bzl", "clang_files")

def _is_include_hdr_test(ctx):
    env = unittest.begin(ctx)

    asserts.true(env, clang_files.is_include_hdr("foo/bar/include/chicken.h"))
    asserts.true(env, clang_files.is_include_hdr("foo/public/chicken.h"))
    asserts.true(env, clang_files.is_include_hdr("public/chicken.h"))
    asserts.false(env, clang_files.is_include_hdr("foo/bar/chicken.h"))

    # Find headers that are not directly under the include directory.
    # Example: https://github.com/SDWebImage/libwebp-Xcode/tree/master/include/webp
    asserts.true(env, clang_files.is_include_hdr("foo/bar/include/chicken/smidgen.h"))
    asserts.false(env, clang_files.is_include_hdr("foo/bar/not_include/chicken/smidgen.h"))
    asserts.false(env, clang_files.is_include_hdr("foo/bar/include_not/chicken/smidgen.h"))

    return unittest.end(env)

is_include_hdr_test = unittest.make(_is_include_hdr_test)

def _is_public_modulemap_test(ctx):
    env = unittest.begin(ctx)

    asserts.true(env, clang_files.is_public_modulemap("foo/bar/module.modulemap"))
    asserts.false(env, clang_files.is_public_modulemap("foo/bar/chicken.modulemap"))

    return unittest.end(env)

is_public_modulemap_test = unittest.make(_is_public_modulemap_test)

def clang_files_test_suite():
    return unittest.suite(
        "clang_files_tests",
        is_include_hdr_test,
        is_public_modulemap_test,
    )
