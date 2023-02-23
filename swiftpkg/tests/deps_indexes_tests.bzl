"""Tests for `deps_indexes.bzl` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")
load("//swiftpkg/internal:deps_indexes.bzl", "deps_indexes")

def _new_from_json_test(ctx):
    env = unittest.begin(ctx)

    actual = _deps_index
    expected_modules = {
        "ArgumentParser": [
            deps_indexes.new_module(
                name = "ArgumentParser",
                c99name = "ArgumentParser",
                src_type = "swift",
                label = bazel_labels.new(
                    repository_name = "@apple_swift_argument_parser",
                    package = "Sources/ArgumentParser",
                    name = "ArgumentParser",
                ),
            ),
        ],
        "Bar": [
            deps_indexes.new_module(
                name = "Bar",
                c99name = "Bar",
                src_type = "swift",
                label = bazel_labels.new(
                    repository_name = "@example_cool_repo",
                    package = "",
                    name = "Bar",
                ),
            ),
            deps_indexes.new_module(
                name = "Bar",
                c99name = "Bar",
                src_type = "swift",
                label = bazel_labels.new(
                    repository_name = "@example_another_repo",
                    package = "Sources/Bar",
                    name = "Bar",
                ),
            ),
        ],
        "Foo": [
            deps_indexes.new_module(
                name = "Foo",
                c99name = "Foo",
                src_type = "swift",
                label = bazel_labels.new(
                    repository_name = "@example_cool_repo",
                    package = "",
                    name = "Foo",
                ),
            ),
            deps_indexes.new_module(
                name = "Foo",
                c99name = "Foo",
                src_type = "swift",
                label = bazel_labels.new(
                    repository_name = "@example_another_repo",
                    package = "Sources/Foo",
                    name = "Foo",
                ),
            ),
        ],
        "ObjcLibrary": [
            deps_indexes.new_module(
                name = "ObjcLibrary",
                c99name = "ObjcLibrary",
                src_type = "objc",
                label = bazel_labels.new(
                    repository_name = "@example_cool_repo",
                    package = "",
                    name = "ObjcLibrary",
                ),
            ),
        ],
    }
    expected = deps_indexes.new(modules = expected_modules)
    asserts.equals(env, expected, actual)

    return unittest.end(env)

new_from_json_test = unittest.make(_new_from_json_test)

def _resolve_module_labels_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "Foo module",
            module = "Foo",
            depender_module_name = "Bar",
            preferred = None,
            restrict_to = [],
            exp = [bazel_labels.new(
                repository_name = "@example_cool_repo",
                package = "",
                name = "Foo",
            )],
        ),
        struct(
            msg = "module not in index",
            module = "DoesNotExist",
            depender_module_name = "DoesNotExist",
            preferred = None,
            restrict_to = [],
            exp = [],
        ),
        struct(
            msg = "preferred repo name exists",
            module = "Foo",
            depender_module_name = "Bar",
            preferred = "example_cool_repo",
            restrict_to = [],
            exp = [bazel_labels.new(
                repository_name = "@example_cool_repo",
                package = "",
                name = "Foo",
            )],
        ),
        struct(
            msg = "preferred repo name not found",
            module = "ArgumentParser",
            depender_module_name = "Bar",
            preferred = "example_another_repo",
            restrict_to = [],
            exp = [bazel_labels.new(
                repository_name = "@apple_swift_argument_parser",
                package = "Sources/ArgumentParser",
                name = "ArgumentParser",
            )],
        ),
        struct(
            msg = "restrict to repos, found one",
            module = "Foo",
            depender_module_name = "Bar",
            preferred = None,
            restrict_to = ["some_other_repo", "example_another_repo"],
            exp = [bazel_labels.new(
                repository_name = "@example_another_repo",
                package = "Sources/Foo",
                name = "Foo",
            )],
        ),
        struct(
            msg = "restrict to repos, not found",
            module = "Foo",
            depender_module_name = "Bar",
            preferred = None,
            restrict_to = ["some_other_repo"],
            exp = [],
        ),
        struct(
            msg = "preferred repo and restrict to repos, found preferred",
            module = "Foo",
            depender_module_name = "Bar",
            preferred = "example_cool_repo",
            restrict_to = ["example_cool_repo", "example_another_repo"],
            exp = [bazel_labels.new(
                repository_name = "@example_cool_repo",
                package = "",
                name = "Foo",
            )],
        ),
        struct(
            msg = "Swift library depends upon Objc library",
            module = "ObjcLibrary",
            depender_module_name = "Bar",
            preferred = None,
            restrict_to = [],
            exp = [
                bazel_labels.new(
                    repository_name = "@example_cool_repo",
                    package = "",
                    name = "ObjcLibrary",
                ),
                bazel_labels.new(
                    repository_name = "@example_cool_repo",
                    package = "",
                    name = "ObjcLibrary_modulemap",
                ),
            ],
        ),
        struct(
            msg = "Objc library depends upon Swift library",
            module = "Foo",
            depender_module_name = "ObjcLibrary",
            preferred = None,
            restrict_to = [],
            exp = [
                bazel_labels.new(
                    repository_name = "@example_cool_repo",
                    package = "",
                    name = "Foo",
                ),
                bazel_labels.new(
                    repository_name = "@example_cool_repo",
                    package = "",
                    name = "Foo_modulemap",
                ),
            ],
        ),
    ]
    for t in tests:
        actual = deps_indexes.resolve_module_labels(
            _deps_index,
            module_name = t.module,
            depender_module_name = t.depender_module_name,
            preferred_repo_name = t.preferred,
            restrict_to_repo_names = t.restrict_to,
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

resolve_module_labels_test = unittest.make(_resolve_module_labels_test)

def _resolve_module_labels_with_ctx_test(ctx):
    env = unittest.begin(ctx)

    deps_index_ctx = deps_indexes.new_ctx(
        deps_index = _deps_index,
        preferred_repo_name = "example_cool_repo",
        restrict_to_repo_names = ["example_cool_repo", "example_another_repo"],
    )
    actuals = deps_indexes.resolve_module_labels_with_ctx(
        deps_index_ctx = deps_index_ctx,
        module_name = "Foo",
        depender_module_name = "Bar",
    )
    asserts.equals(env, 1, len(actuals))
    actual = actuals[0]
    asserts.equals(env, "@example_cool_repo", actual.repository_name)
    asserts.equals(env, "Foo", actual.name)

    return unittest.end(env)

resolve_module_labels_with_ctx_test = unittest.make(_resolve_module_labels_with_ctx_test)

def deps_indexes_test_suite():
    return unittest.suite(
        "deps_indexes_tests",
        new_from_json_test,
        resolve_module_labels_test,
        resolve_module_labels_with_ctx_test,
    )

_deps_index_json = """
{
  "modules": [
    {"name": "ArgumentParser", "c99name": "ArgumentParser", "src_type": "swift", "label": "@apple_swift_argument_parser//Sources/ArgumentParser"},
    {"name": "Foo", "c99name": "Foo", "src_type": "swift", "label": "@example_cool_repo//:Foo"},
    {"name": "Foo", "c99name": "Foo", "src_type": "swift", "label": "@example_another_repo//Sources/Foo"},
    {"name": "Bar", "c99name": "Bar", "src_type": "swift", "label": "@example_cool_repo//:Bar"},
    {"name": "Bar", "c99name": "Bar", "src_type": "swift", "label": "@example_another_repo//Sources/Bar"},
    {"name": "ObjcLibrary", "c99name": "ObjcLibrary", "src_type": "objc", "label": "@example_cool_repo//:ObjcLibrary"}
  ],
  "products": []
}
"""

_deps_index = deps_indexes.new_from_json(_deps_index_json)
