"""Tests for `repo_rules` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:repo_rules.bzl", "repo_rules")

def _make_files_read_only_test(ctx):
    env = unittest.begin(ctx)

    calls = []

    def execute(args, quiet = False):
        calls.append(struct(args = args, quiet = quiet))
        return struct(
            return_code = 0,
            stdout = "",
            stderr = "",
        )

    repository_ctx = struct(
        execute = execute,
        os = struct(name = "linux"),
    )

    repo_rules.make_files_read_only(repository_ctx, "/tmp/swiftpkg")

    asserts.equals(env, 1, len(calls), "expected a single chmod invocation")
    asserts.equals(
        env,
        [
            "find",
            "/tmp/swiftpkg",
            "-type",
            "f",
            "-exec",
            "chmod",
            "a-w",
            "{}",
            "+",
        ],
        calls[0].args,
        "expected the repository files to be marked read-only",
    )
    asserts.true(env, calls[0].quiet, "expected chmod invocation to be quiet")

    return unittest.end(env)

make_files_read_only_test = unittest.make(_make_files_read_only_test)

def _make_files_read_only_windows_noop_test(ctx):
    env = unittest.begin(ctx)

    calls = []

    def execute(args, quiet = False):
        calls.append(struct(args = args, quiet = quiet))
        return struct(
            return_code = 0,
            stdout = "",
            stderr = "",
        )

    repository_ctx = struct(
        execute = execute,
        os = struct(name = "windows"),
    )

    repo_rules.make_files_read_only(repository_ctx, "C:/tmp/swiftpkg")

    asserts.equals(env, [], calls, "expected no chmod invocation on Windows")

    return unittest.end(env)

make_files_read_only_windows_noop_test = unittest.make(
    _make_files_read_only_windows_noop_test,
)

def repo_rules_test_suite():
    return unittest.suite(
        "repo_rules_tests",
        make_files_read_only_test,
        make_files_read_only_windows_noop_test,
    )
