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

def module_indexes_test_suite():
    return unittest.suite(
        "module_indexes_tests",
        new_from_json_test,
    )

_module_index_json = """
{
  "ArgumentParser": [
    "@apple_swift_argument_parser//Sources/ArgumentParser"
  ],
  "Generate_Manual": [
    "@apple_swift_argument_parser//Plugins/GenerateManualPlugin:Generate_Manual"
  ],
  "Logging": [
    "@apple_swift_log//Sources/Logging"
  ]
}
"""
