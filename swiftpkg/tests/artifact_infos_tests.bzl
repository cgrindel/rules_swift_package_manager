"""Tests for `artifact_infos` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:artifact_infos.bzl", "artifact_infos", "link_types")
load(":testutils.bzl", "testutils")

def _link_type_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "current ar archive",
            file_type = """\
path/to/framework/binary/FooBar (for architecture x86_64):	current ar archive
path/to/framework/binary/FooBar (for architecture arm64):	current ar archive
""",
            exp = link_types.static,
        ),
        struct(
            msg = "current ar archive random library",
            file_type = """\
Mach-O universal binary with 2 architectures: [x86_64:current ar archive random library] [arm64:current ar archive random library]
path/to/framework/binary/FooBar (for architecture x86_64):	current ar archive random library
path/to/framework/binary/FooBar (for architecture arm64):	current ar archive random library
""",
            exp = link_types.static,
        ),
        struct(
            msg = "dynamically linked shared library",
            file_type = "dynamically linked shared library",
            exp = link_types.dynamic,
        ),
        struct(
            msg = "unknown",
            file_type = "no idea what this is",
            exp = link_types.unknown,
        ),
    ]
    for t in tests:
        path = "path/to/framework/binary/FooBar"
        stub_repository_ctx = testutils.new_stub_repository_ctx(
            repo_name = "chicken",
            file_type_results = {path: t.file_type},
        )
        actual = artifact_infos.link_type(stub_repository_ctx, "path/to/framework/binary/FooBar")
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

link_type_test = unittest.make(_link_type_test)

def artifact_infos_test_suite(name = "artifact_infos_tests"):
    return unittest.suite(
        name,
        link_type_test,
    )
