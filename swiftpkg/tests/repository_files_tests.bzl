"""Tests for `repository_files` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:repository_files.bzl", "repository_files")

def _exclude_paths_test(ctx):
    env = unittest.begin(ctx)

    rel_path_list = [
        "foo/bar.txt",
        "bar/hello",
        "bar/hello/README.md",
        "bar/hello.txt",
        "bar/goodbye",
    ]

    tests = [
        struct(
            msg = "no exlcudes",
            exclude = [],
            path_list = rel_path_list,
            expected = rel_path_list,
        ),
        struct(
            msg = "exclude bar directory",
            exclude = ["bar"],
            path_list = rel_path_list,
            expected = [
                "foo/bar.txt",
            ],
        ),
        struct(
            msg = "exclude bar/hello directory",
            exclude = ["bar/hello"],
            path_list = rel_path_list,
            expected = [
                "foo/bar.txt",
                "bar/hello.txt",  # This should not be filtered out
                "bar/goodbye",
            ],
        ),
        struct(
            msg = "exclude bar/hello.txt file",
            exclude = ["bar/hello.txt"],
            path_list = rel_path_list,
            expected = [
                "foo/bar.txt",
                "bar/hello",
                "bar/hello/README.md",
                "bar/goodbye",
            ],
        ),
        struct(
            msg = "multiple excludes",
            exclude = ["bar/hello", "foo"],
            path_list = rel_path_list,
            expected = [
                "bar/hello.txt",
                "bar/goodbye",
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
