"""Tests for `deps_indexes.bzl` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")
load("//swiftpkg/internal:deps_indexes.bzl", "deps_indexes")

def _new_from_json_test(ctx):
    env = unittest.begin(ctx)

    actual = _deps_index
    expected_modules = {
        "ArgumentParser": [
            bazel_labels.new(
                repository_name = "@apple_swift_argument_parser",
                package = "Sources/ArgumentParser",
                name = "ArgumentParser",
            ),
        ],
        "Foo": [
            bazel_labels.new(
                repository_name = "@example_cool_repo",
                package = "",
                name = "Foo",
            ),
            bazel_labels.new(
                repository_name = "@example_another_repo",
                package = "Sources/Foo",
                name = "Foo",
            ),
        ],
        "Generate_Manual": [
            bazel_labels.new(
                repository_name = "@apple_swift_argument_parser",
                package = "Plugins/GenerateManualPlugin",
                name = "Generate_Manual",
            ),
        ],
        "Logging": [
            bazel_labels.new(
                repository_name = "@apple_swift_log",
                package = "Sources/Logging",
                name = "Logging",
            ),
        ],
    }
    expected = deps_indexes.new(modules = expected_modules)
    asserts.equals(env, expected, actual)

    return unittest.end(env)

new_from_json_test = unittest.make(_new_from_json_test)

def _resolve_module_label_test(ctx):
    env = unittest.begin(ctx)

    # Find any label that provides Foo
    actual = deps_indexes.resolve_module_label(_deps_index, "Foo")
    asserts.equals(env, "@example_cool_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    # Module not in index
    actual = deps_indexes.resolve_module_label(_deps_index, "Bar")
    asserts.equals(env, None, actual)

    # Preferred repo name exists
    actual = deps_indexes.resolve_module_label(
        _deps_index,
        "Foo",
        preferred_repo_name = "example_another_repo",
    )
    asserts.equals(env, "@example_another_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    # Preferred repo name not found
    actual = deps_indexes.resolve_module_label(
        _deps_index,
        "ArgumentParser",
        preferred_repo_name = "example_another_repo",
    )
    asserts.equals(env, "@apple_swift_argument_parser", actual.repository_name)
    asserts.equals(env, "ArgumentParser", actual.name)

    # Restrict to repos, found one
    actual = deps_indexes.resolve_module_label(
        _deps_index,
        "Foo",
        restrict_to_repo_names = ["some_other_repo", "example_another_repo"],
    )
    asserts.equals(env, "@example_another_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    # Restrict to repos, not found
    actual = deps_indexes.resolve_module_label(
        _deps_index,
        "Foo",
        restrict_to_repo_names = ["some_other_repo"],
    )
    asserts.equals(env, None, actual)

    # Preferred repo and restrict to repos, found preferred
    actual = deps_indexes.resolve_module_label(
        _deps_index,
        "Foo",
        preferred_repo_name = "example_cool_repo",
        restrict_to_repo_names = ["example_cool_repo", "example_another_repo"],
    )
    asserts.equals(env, "@example_cool_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    # Preferred repo and restrict to repos, found not preferred
    actual = deps_indexes.resolve_module_label(
        _deps_index,
        "Foo",
        preferred_repo_name = "some_other_repo",
        restrict_to_repo_names = ["some_other_repo", "example_another_repo"],
    )
    asserts.equals(env, "@example_another_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    return unittest.end(env)

resolve_module_label_test = unittest.make(_resolve_module_label_test)

def _resolve_module_label_with_ctx_test(ctx):
    env = unittest.begin(ctx)

    deps_index_ctx = deps_indexes.new_ctx(
        deps_index = _deps_index,
        preferred_repo_name = "example_cool_repo",
        restrict_to_repo_names = ["example_cool_repo", "example_another_repo"],
    )
    actual = deps_indexes.resolve_module_label_with_ctx(deps_index_ctx, "Foo")
    asserts.equals(env, "@example_cool_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    return unittest.end(env)

resolve_module_label_with_ctx_test = unittest.make(_resolve_module_label_with_ctx_test)

def deps_indexes_test_suite():
    return unittest.suite(
        "deps_indexes_tests",
        new_from_json_test,
        resolve_module_label_test,
        resolve_module_label_with_ctx_test,
    )

_deps_index_json = """
{
  "modules": {
    "ArgumentParser": [
      "@apple_swift_argument_parser//Sources/ArgumentParser"
    ],
    "Foo": [
      "@example_cool_repo//:Foo",
      "@example_another_repo//Sources/Foo"
    ],
    "Generate_Manual": [
      "@apple_swift_argument_parser//Plugins/GenerateManualPlugin:Generate_Manual"
    ],
    "Logging": [
      "@apple_swift_log//Sources/Logging"
    ]
  },
  "products": {}
}
"""

_deps_index = deps_indexes.new_from_json(_deps_index_json)
