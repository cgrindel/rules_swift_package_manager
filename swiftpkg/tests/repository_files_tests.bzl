"""Tests for `repository_files` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:repository_files.bzl", "repository_files")

_path_list = [
    "/foo/chicken.txt",
    "/foo/smidgen.txt",
    "/bar/hello",
    "/bar/goodbye",
    "/bar/smile/big",
]

def _exclude_paths_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(exclude = [], expected = _path_list, msg = "no excludes"),
        struct(exclude = ["/foo"], expected = _path_list, msg = "dir specified as file"),
        struct(exclude = ["/foo/"], expected = [
            "/bar/hello",
            "/bar/goodbye",
            "/bar/smile/big",
        ], msg = "exclude foo dir"),
        struct(exclude = ["/foo/", "/bar/smile/big"], expected = [
            "/bar/hello",
            "/bar/goodbye",
        ], msg = "exclude foo dir and a file under bar"),
    ]

    for test in tests:
        actual = repository_files.exclude_paths(_path_list, test.exclude)
        asserts.equals(env, test.expected, actual, test.msg)

    return unittest.end(env)

exclude_paths_test = unittest.make(_exclude_paths_test)

def repository_files_test_suite():
    return unittest.suite(
        "repository_files_tests",
        exclude_paths_test,
    )
