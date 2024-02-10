"""Tests for `resource_files` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:resource_files.bzl", "resource_files")

def _is_auto_discovered_resource_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(msg = "nib", path = "foo.nib", exp = True),
        struct(msg = "xib", path = "foo.xib", exp = True),
        struct(msg = "storyboard", path = "foo.storyboard", exp = True),
        struct(msg = "xcassets dir", path = "foo.xcassets", exp = False),
        struct(
            msg = "file under xcassets dir",
            path = "foo.xcassets/bar.png",
            exp = True,
        ),
        struct(msg = "xcstrings", path = "foo.xcstrings", exp = True),
        struct(msg = "xcdatamodeld", path = "foo.xcdatamodeld", exp = False),
        struct(
            msg = "content under .xcdatamodeld",
            path = "foo.xcdatamodeld/bar.xcdatamodel/content",
            exp = True,
        ),
        struct(msg = "xcmappingmodel", path = "foo.xcmappingmodel", exp = True),
        struct(msg = "metal", path = "foo.metal", exp = True),
        struct(msg = "swift", path = "foo.swift", exp = False),
    ]
    for t in tests:
        actual = resource_files.is_auto_discovered_resource(t.path)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

is_auto_discovered_resource_test = unittest.make(_is_auto_discovered_resource_test)

def resource_files_test_suite(name = "resource_files_tests"):
    return unittest.suite(
        name,
        is_auto_discovered_resource_test,
    )
