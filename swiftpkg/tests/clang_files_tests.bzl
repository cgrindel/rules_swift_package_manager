"""Tests for clang_files."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:clang_files.bzl", "clang_files")

def _is_hdr_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(path = "foo.h", exp = True, msg = ".h"),
        struct(path = "foo.hh", exp = True, msg = ".hh"),
        struct(path = "foo.hpp", exp = True, msg = ".hpp"),
        struct(path = "foo.hxx", exp = True, msg = ".hxx"),
        struct(path = "foo.inl", exp = True, msg = ".inl"),
        struct(path = "foo.H", exp = True, msg = ".H"),
        struct(path = "foo", exp = False, msg = "no extension"),
        struct(path = "foo.c", exp = False, msg = "wrong extension"),
    ]
    for t in tests:
        actual = clang_files.is_hdr(t.path)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

is_hdr_test = unittest.make(_is_hdr_test)

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

    asserts.true(
        env,
        clang_files.is_public_modulemap(
            "foo/bar/module.modulemap",
            public_includes = ["foo/bar"],
        ),
    )
    asserts.false(env, clang_files.is_public_modulemap("foo/bar/module.modulemap"))
    asserts.false(env, clang_files.is_public_modulemap("foo/bar/chicken.modulemap"))

    return unittest.end(env)

is_public_modulemap_test = unittest.make(_is_public_modulemap_test)

def _relativize_test(ctx):
    env = unittest.begin(ctx)

    relative_to = "/path/to/parent"
    tests = [
        struct(
            path = relative_to,
            relative_to = relative_to,
            exp = ".",
            msg = "path is equal to relative_to",
        ),
        struct(
            path = paths.join(relative_to, "foo/bar"),
            relative_to = relative_to,
            exp = "foo/bar",
            msg = "path is under relative_to",
        ),
        struct(
            path = "/another/path",
            relative_to = relative_to,
            exp = "/another/path",
            msg = "path is not under relative_to",
        ),
        struct(
            path = paths.join(relative_to, "foo/bar"),
            relative_to = None,
            exp = paths.join(relative_to, "foo/bar"),
            msg = "no relative_to",
        ),
    ]
    for t in tests:
        actual = clang_files.relativize(t.path, t.relative_to)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

relativize_test = unittest.make(_relativize_test)

def _is_under_path_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            path = "/parent",
            parent = "/parent",
            exp = True,
            msg = "path equals parent",
        ),
        struct(
            path = "/parent/foo",
            parent = "/parent",
            exp = True,
            msg = "path is under parent",
        ),
        struct(
            path = "/parent",
            parent = "/parent/",
            exp = True,
            msg = "path equals parent, parent has trailing slash",
        ),
        struct(
            path = "/parent.txt",
            parent = "/parent",
            exp = False,
            msg = "path has similar prefix to parent",
        ),
        struct(
            path = "/another",
            parent = "/parent",
            exp = False,
            msg = "path is not under parent",
        ),
    ]
    for t in tests:
        actual = clang_files.is_under_path(t.path, t.parent)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

is_under_path_test = unittest.make(_is_under_path_test)

def _find_magical_public_hdr_dir_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "include at beginning",
            path = "include/",
            exp = "include",
        ),
        struct(
            msg = "include in the middle",
            path = "path/to/include/foo",
            exp = "path/to/include",
        ),
        struct(
            msg = "include part of name",
            path = "path/to/bar_include/foo",
            exp = None,
        ),
        struct(
            msg = "public at beginning",
            path = "public/",
            exp = "public",
        ),
        struct(
            msg = "public in the middle",
            path = "path/to/public/foo",
            exp = "path/to/public",
        ),
        struct(
            msg = "public part of name",
            path = "path/to/bar_public/foo",
            exp = None,
        ),
    ]
    for t in tests:
        actual = clang_files.find_magical_public_hdr_dir(t.path)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

find_magical_public_hdr_dir_test = unittest.make(_find_magical_public_hdr_dir_test)

def _reduce_paths_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "empty paths",
            paths = [],
            exp = [],
        ),
        struct(
            msg = "single path",
            paths = ["Sources/geos/include"],
            exp = ["Sources/geos/include"],
        ),
        struct(
            msg = "duplicate paths",
            paths = [
                "Sources/geos/include",
                "Sources/geos/include",
            ],
            exp = ["Sources/geos/include"],
        ),
        struct(
            msg = "consolidate paths",
            paths = [
                "Sources/geos/include/geos/geomgraph",
                "Sources/geos/include/geos/geomgraph/index",
                "Sources/geos/include/geos/operation",
                "Sources/geos/include",
            ],
            exp = ["Sources/geos/include"],
        ),
        struct(
            msg = "consolidate paths, multiple results",
            paths = [
                "Sources/geos/include/geos/geomgraph",
                "Sources/geos/include/geos/geomgraph/index",
                "Sources/geos/include/geos/operation",
                "Sources/geos/include",
                "Sources/geos/src/deps/ryu",
            ],
            exp = [
                "Sources/geos/include",
                "Sources/geos/src/deps/ryu",
            ],
        ),
    ]
    for t in tests:
        actual = clang_files.reduce_paths(t.paths)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

reduce_paths_test = unittest.make(_reduce_paths_test)

def _organize_srcs_test(ctx):
    env = unittest.begin(ctx)

    srcs = [
        "foo.cc",
        "foo.c",
        "foo.inc",
        "foo.cpp",
        "foo.m",
        "foo.so",
        "foo.mm",
        "foo.o",
        "foo.S",
    ]
    actual = clang_files.organize_srcs(srcs)
    expected = struct(
        c_srcs = ["foo.c"],
        cxx_srcs = ["foo.cc", "foo.cpp"],
        objc_srcs = ["foo.m"],
        objcxx_srcs = ["foo.mm"],
        assembly_srcs = ["foo.S"],
        other_srcs = ["foo.inc", "foo.so", "foo.o"],
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

organize_srcs_test = unittest.make(_organize_srcs_test)

def clang_files_test_suite():
    return unittest.suite(
        "clang_files_tests",
        organize_srcs_test,
        is_hdr_test,
        is_include_hdr_test,
        is_public_modulemap_test,
        relativize_test,
        is_under_path_test,
        find_magical_public_hdr_dir_test,
        reduce_paths_test,
    )
