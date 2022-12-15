"""Tests for `module_indexes.bzl` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")
load("//swiftpkg/internal:module_indexes.bzl", "module_indexes")

def _new_from_json_test(ctx):
    env = unittest.begin(ctx)

    actual = module_indexes.new_from_json(_module_index_json)
    expected = {
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
    asserts.equals(env, expected, actual)

    return unittest.end(env)

new_from_json_test = unittest.make(_new_from_json_test)

def _find_test(ctx):
    env = unittest.begin(ctx)

    module_index = module_indexes.new_from_json(_module_index_json)

    # Find any label that provides Foo
    actual = module_indexes.find(module_index, "Foo")
    asserts.equals(env, "@example_cool_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    # Module not in index
    actual = module_indexes.find(module_index, "Bar")
    asserts.equals(env, None, actual)

    # Preferred repo name exists
    actual = module_indexes.find(
        module_index,
        "Foo",
        preferred_repo_name = "example_another_repo",
    )
    asserts.equals(env, "@example_another_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    # Preferred repo name not found
    actual = module_indexes.find(
        module_index,
        "ArgumentParser",
        preferred_repo_name = "example_another_repo",
    )
    asserts.equals(env, "@apple_swift_argument_parser", actual.repository_name)
    asserts.equals(env, "ArgumentParser", actual.name)

    # Restrict to repos, found one
    actual = module_indexes.find(
        module_index,
        "Foo",
        restrict_to_repo_names = ["some_other_repo", "example_another_repo"],
    )
    asserts.equals(env, "@example_another_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    # Restrict to repos, not found
    actual = module_indexes.find(
        module_index,
        "Foo",
        restrict_to_repo_names = ["some_other_repo"],
    )
    asserts.equals(env, None, actual)

    # Preferred repo and restrict to repos, found preferred
    actual = module_indexes.find(
        module_index,
        "Foo",
        preferred_repo_name = "example_cool_repo",
        restrict_to_repo_names = ["example_cool_repo", "example_another_repo"],
    )
    asserts.equals(env, "@example_cool_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    # Preferred repo and restrict to repos, found not preferred
    actual = module_indexes.find(
        module_index,
        "Foo",
        preferred_repo_name = "some_other_repo",
        restrict_to_repo_names = ["some_other_repo", "example_another_repo"],
    )
    asserts.equals(env, "@example_another_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    return unittest.end(env)

find_test = unittest.make(_find_test)

def module_indexes_test_suite():
    return unittest.suite(
        "module_indexes_tests",
        new_from_json_test,
        find_test,
    )

_module_index_json = """
{
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
}
"""
