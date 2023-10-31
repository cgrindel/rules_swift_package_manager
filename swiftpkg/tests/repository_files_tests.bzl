"""Tests for `repository_files` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:repository_files.bzl", "repository_files")

def _exclude_paths_test(ctx):
    env = unittest.begin(ctx)

    abs_path_list = [
        "/foo/chicken.txt",
        "/foo/smidgen.txt",
        "/bar/hello",
        "/bar/goodbye",
        "/bar/smile/big",
    ]
    rel_path_list = [
        "foo/chicken.txt",
        "foo/smidgen.txt",
        "bar/hello",
        "bar/goodbye",
        "bar/smile/big",
    ]

    tests = [
        struct(
            msg = "absolute paths, no excludes",
            exclude = [],
            path_list = abs_path_list,
            expected = abs_path_list,
        ),
        struct(
            msg = "absolute paths, dir specified as file",
            exclude = ["/foo"],
            path_list = abs_path_list,
            expected = abs_path_list,
        ),
        struct(
            msg = "absolute paths, exclude foo dir",
            exclude = ["/foo/"],
            path_list = abs_path_list,
            expected = [
                "/bar/hello",
                "/bar/goodbye",
                "/bar/smile/big",
            ],
        ),
        struct(
            msg = "absolute paths, exclude foo dir and a file under bar",
            exclude = ["/foo/", "/bar/smile/big"],
            path_list = abs_path_list,
            expected = [
                "/bar/hello",
                "/bar/goodbye",
            ],
        ),
        struct(
            msg = "relative paths, dir specified as file",
            exclude = ["foo"],
            path_list = rel_path_list,
            expected = [
                "bar/hello",
                "bar/goodbye",
                "bar/smile/big",
            ],
        ),
    ]

    for test in tests:
        actual = repository_files.exclude_paths(test.path_list, test.exclude)
        asserts.equals(env, test.expected, actual, test.msg)

    return unittest.end(env)

exclude_paths_test = unittest.make(_exclude_paths_test)

def _process_find_results_test(ctx):
    env = unittest.begin(ctx)

    raw_no_dot_prefix = """\
output
output/foo
output/foo/baz
output/foo/baz/elephant.txt
output/foo/bar
output/foo/bar/monkey.txt
output/chicken
output/chicken/smidgen
output/chicken/smidgen/hello.txt
"""
    raw_with_dot_prefix = """\
./foo
./foo/baz
./foo/baz/elephant.txt
./foo/bar
./foo/bar/monkey.txt
./chicken
./chicken/smidgen
./chicken/smidgen/hello.txt
"""

    tests = [
        struct(
            msg = "find output: no excludes, no prefix cleanup",
            raw = raw_no_dot_prefix,
            find_path = "output",
            exclude_paths = [],
            exp = [
                "output/foo",
                "output/foo/baz",
                "output/foo/baz/elephant.txt",
                "output/foo/bar",
                "output/foo/bar/monkey.txt",
                "output/chicken",
                "output/chicken/smidgen",
                "output/chicken/smidgen/hello.txt",
            ],
        ),
        struct(
            msg = "find .: no excludes, with prefix cleanup",
            raw = raw_with_dot_prefix,
            find_path = ".",
            exclude_paths = [],
            exp = [
                "foo",
                "foo/baz",
                "foo/baz/elephant.txt",
                "foo/bar",
                "foo/bar/monkey.txt",
                "chicken",
                "chicken/smidgen",
                "chicken/smidgen/hello.txt",
            ],
        ),
        struct(
            msg = "find output: with excludes, no prefix cleanup",
            raw = raw_no_dot_prefix,
            find_path = "output",
            exclude_paths = ["output/foo/baz", "output/chicken"],
            exp = [
                "output/foo",
                "output/foo/bar",
                "output/foo/bar/monkey.txt",
            ],
        ),
    ]
    for t in tests:
        actual = repository_files.process_find_results(
            t.raw,
            find_path = t.find_path,
            exclude_paths = t.exclude_paths,
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

process_find_results_test = unittest.make(_process_find_results_test)

def repository_files_test_suite():
    return unittest.suite(
        "repository_files_tests",
        exclude_paths_test,
        process_find_results_test,
    )
