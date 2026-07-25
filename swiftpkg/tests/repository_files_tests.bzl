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
        actual = repository_files.exclude_paths(".", test.path_list, test.exclude)
        asserts.equals(env, test.expected, actual, test.msg)

    return unittest.end(env)

exclude_paths_test = unittest.make(_exclude_paths_test)

def _exclude_paths_with_find_path_test(ctx):
    env = unittest.begin(ctx)

    prefixed_path_list = [
        "ios/Market/Sources/main.swift",
        "ios/Market/App/AppDelegate.swift",
        "ios/Market/App/Info.plist",
        "ios/Market/Resources/image.png",
    ]

    tests = [
        struct(
            msg = "relative exclude with find_path prefix",
            find_path = "ios/Market",
            exclude = ["App"],
            path_list = prefixed_path_list,
            expected = [
                "ios/Market/Sources/main.swift",
                "ios/Market/Resources/image.png",
            ],
        ),
        struct(
            msg = "fully qualified exclude (idempotent)",
            find_path = "ios/Market",
            exclude = ["ios/Market/App"],
            path_list = prefixed_path_list,
            expected = [
                "ios/Market/Sources/main.swift",
                "ios/Market/Resources/image.png",
            ],
        ),
        struct(
            msg = "exclude file with find_path prefix",
            find_path = "ios/Market",
            exclude = ["App/Info.plist"],
            path_list = prefixed_path_list,
            expected = [
                "ios/Market/Sources/main.swift",
                "ios/Market/App/AppDelegate.swift",
                "ios/Market/Resources/image.png",
            ],
        ),
        struct(
            msg = "multiple relative excludes with find_path",
            find_path = "ios/Market",
            exclude = ["App", "Resources"],
            path_list = prefixed_path_list,
            expected = [
                "ios/Market/Sources/main.swift",
            ],
        ),
    ]

    for test in tests:
        actual = repository_files.exclude_paths(
            test.find_path,
            test.path_list,
            test.exclude,
        )
        asserts.equals(env, test.expected, actual, test.msg)

    return unittest.end(env)

exclude_paths_with_find_path_test = unittest.make(_exclude_paths_with_find_path_test)

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
            msg = "no excludes, no prefix cleanup, no remove_find_path",
            raw = raw_no_dot_prefix,
            find_path = "output",
            exclude_paths = [],
            remove_find_path = False,
            exp = [
                "output",
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
            msg = "no excludes, with prefix cleanup, no remove_find_path",
            raw = raw_with_dot_prefix,
            find_path = ".",
            exclude_paths = [],
            remove_find_path = False,
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
            msg = "with excludes, no prefix cleanup, no remove_find_path",
            raw = raw_no_dot_prefix,
            find_path = "output",
            exclude_paths = ["output/foo/baz", "output/chicken"],
            remove_find_path = False,
            exp = [
                "output",
                "output/foo",
                "output/foo/bar",
                "output/foo/bar/monkey.txt",
            ],
        ),
        struct(
            msg = "no excludes, no prefix cleanup, with remove_find_path",
            raw = raw_no_dot_prefix,
            find_path = "output",
            exclude_paths = [],
            remove_find_path = True,
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
            msg = "with excludes, no prefix cleanup, with remove_find_path",
            raw = raw_no_dot_prefix,
            find_path = "output",
            exclude_paths = ["output/foo"],
            remove_find_path = True,
            exp = [
                "output/chicken",
                "output/chicken/smidgen",
                "output/chicken/smidgen/hello.txt",
            ],
        ),
    ]
    for t in tests:
        actual = repository_files.process_find_results(
            t.raw,
            find_path = t.find_path,
            exclude_paths = t.exclude_paths,
            remove_find_path = t.remove_find_path,
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

process_find_results_test = unittest.make(_process_find_results_test)

def _parse_od_output_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "BSD od pads every byte with a leading space",
            raw = " cf fa ed fe\n",
            count = 4,
            exp = ["cf", "fa", "ed", "fe"],
        ),
        struct(
            msg = "GNU od indents the row",
            raw = "  cf fa ed fe\n",
            count = 4,
            exp = ["cf", "fa", "ed", "fe"],
        ),
        struct(
            msg = "no trailing newline",
            raw = " 21 3c 61 72",
            count = 4,
            exp = ["21", "3c", "61", "72"],
        ),
        struct(
            msg = "output wrapped across rows",
            raw = " 00 00 00 00 00 00 00 00\n 00 00 10 00\n",
            count = 12,
            exp = [
                "00",
                "00",
                "00",
                "00",
                "00",
                "00",
                "00",
                "00",
                "00",
                "00",
                "10",
                "00",
            ],
        ),
        struct(
            msg = "tabs and carriage returns are separators",
            raw = "\tcf\tfa\r\ned\tfe\r\n",
            count = 4,
            exp = ["cf", "fa", "ed", "fe"],
        ),
        struct(
            msg = "uppercase bytes are normalized",
            raw = " CF FA ED FE\n",
            count = 4,
            exp = ["cf", "fa", "ed", "fe"],
        ),
        struct(
            # od stops at the end of the file, so a header prefix read can come
            # back short. An ar archive is identified by its first four bytes,
            # so this has to be allowed rather than treated as an error.
            msg = "a short read returns the bytes that were available",
            raw = " 21 3c 61 72 63 68 3e 0a\n",
            count = 24,
            exp = ["21", "3c", "61", "72", "63", "68", "3e", "0a"],
        ),
    ]
    for t in tests:
        actual = repository_files.parse_od_output(
            t.raw,
            t.count,
            "path/to/binary",
            0,
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

parse_od_output_test = unittest.make(_parse_od_output_test)

def repository_files_test_suite():
    return unittest.suite(
        "repository_files_tests",
        exclude_paths_test,
        exclude_paths_with_find_path_test,
        parse_od_output_test,
        process_find_results_test,
    )
