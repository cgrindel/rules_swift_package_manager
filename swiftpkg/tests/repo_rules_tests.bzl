"""Tests for `repo_rules` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:repo_rules.bzl", "repo_rules")

def _gen_build_files_with_build_file_test(ctx):
    """When build_file is set, gen_build_files should use it and skip \
    generation."""
    env = unittest.begin(ctx)

    # Track that template was called with the expected arguments.
    calls = {"template": []}

    def _template(path, label):
        calls["template"].append(struct(path = path, label = label))

    build_file_label = "//some/pkg:BUILD.custom"
    repository_ctx = struct(
        attr = struct(build_file = build_file_label),
        template = _template,
    )

    # Pass None for pkg_ctx. If the early return is bypassed, the function
    # will fail trying to access pkg_ctx.pkg_info, making the failure obvious.
    repo_rules.gen_build_files(repository_ctx, None)

    asserts.equals(
        env,
        1,
        len(calls["template"]),
        "template should be called exactly once",
    )
    asserts.equals(
        env,
        "BUILD.bazel",
        calls["template"][0].path,
        "template output path should be BUILD.bazel",
    )
    asserts.equals(
        env,
        build_file_label,
        calls["template"][0].label,
        "template should receive the build_file label",
    )

    return unittest.end(env)

gen_build_files_with_build_file_test = unittest.make(
    _gen_build_files_with_build_file_test,
)

def _gen_build_files_without_build_file_test(ctx):
    """When build_file is None, gen_build_files should proceed with normal \
    generation."""
    env = unittest.begin(ctx)

    # Track calls to template — it should NOT be called.
    calls = {"file": [], "template": []}

    def _template(path, label):
        calls["template"].append(struct(path = path, label = label))

    # buildifier: disable=unused-variable
    def _file(path, content = "", executable = False, legacy_utf8 = False):
        calls["file"].append(struct(path = path))

    # buildifier: disable=unused-variable
    def _execute(args, environment = {}, quiet = True):
        # Return empty results for find commands (license file search).
        return struct(return_code = 0, stdout = "", stderr = "")

    repository_ctx = struct(
        attr = struct(build_file = None),
        name = "bzlmodmangled~test_pkg",
        template = _template,
        file = _file,
        execute = _execute,
    )

    pkg_info = struct(
        name = "TestPkg",
        url = "https://github.com/example/test-pkg",
        version = "1.0.0",
        path = "",
        targets = [],
        products = [],
    )
    pkg_ctx = struct(pkg_info = pkg_info)

    repo_rules.gen_build_files(repository_ctx, pkg_ctx)

    asserts.equals(
        env,
        0,
        len(calls["template"]),
        "template should not be called when build_file is None",
    )

    # Verify that the normal generation path wrote a BUILD file.
    asserts.true(
        env,
        len(calls["file"]) > 0,
        "file should be called to write the generated BUILD file",
    )

    return unittest.end(env)

gen_build_files_without_build_file_test = unittest.make(
    _gen_build_files_without_build_file_test,
)

def repo_rules_test_suite():
    return unittest.suite(
        "repo_rules_tests",
        gen_build_files_with_build_file_test,
        gen_build_files_without_build_file_test,
    )
