"""Tests for `deps_indexes.bzl` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")
load("//swiftpkg/internal:deps_indexes.bzl", "deps_indexes", "src_types")

def _new_from_json_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, 4, len(_deps_index.modules_by_name), "modules_by_name len")
    asserts.equals(env, 6, len(_deps_index.modules_by_label), "modules_by_label len")
    asserts.equals(env, 3, len(_deps_index.products_by_key), "products_by_key len")
    asserts.equals(env, 2, len(_deps_index.products_by_name), "products_by_name len")
    asserts.equals(env, 1, len(_deps_index.products_by_name["ArgumentParser"]), "number of ArgumentParser products")
    asserts.equals(env, 2, len(_deps_index.products_by_name["Foo"]), "number of Foo products")

    return unittest.end(env)

new_from_json_test = unittest.make(_new_from_json_test)

def _get_module_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "label is a string",
            label = "@apple_swift_argument_parser//Sources/ArgumentParser",
            exp_name = "ArgumentParser",
        ),
        struct(
            msg = "label is a struct",
            label = bazel_labels.parse(
                "@apple_swift_argument_parser//Sources/ArgumentParser",
            ),
            exp_name = "ArgumentParser",
        ),
    ]
    for t in tests:
        actual = deps_indexes.get_module(_deps_index, t.label)
        asserts.equals(
            env,
            bazel_labels.normalize(t.label),
            bazel_labels.normalize(actual.label),
            t.msg,
        )
        asserts.equals(env, t.exp_name, actual.name, t.msg)

    return unittest.end(env)

get_module_test = unittest.make(_get_module_test)

def _resolve_module_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "Foo module",
            module = "Foo",
            preferred = None,
            restrict_to = [],
            exp = bazel_labels.new(
                repository_name = "@example_cool_repo",
                package = "",
                name = "Foo",
            ),
        ),
        struct(
            msg = "module not in index",
            module = "DoesNotExist",
            preferred = None,
            restrict_to = [],
            exp = None,
        ),
        struct(
            msg = "preferred repo name exists",
            module = "Foo",
            preferred = "example_cool_repo",
            restrict_to = [],
            exp = bazel_labels.new(
                repository_name = "@example_cool_repo",
                package = "",
                name = "Foo",
            ),
        ),
        struct(
            msg = "preferred repo name not found",
            module = "ArgumentParser",
            preferred = "example_another_repo",
            restrict_to = [],
            exp = bazel_labels.new(
                repository_name = "@apple_swift_argument_parser",
                package = "Sources/ArgumentParser",
                name = "ArgumentParser",
            ),
        ),
        struct(
            msg = "restrict to repos, found one",
            module = "Foo",
            preferred = None,
            restrict_to = ["some_other_repo", "example_another_repo"],
            exp = bazel_labels.new(
                repository_name = "@example_another_repo",
                package = "Sources/Foo",
                name = "Foo",
            ),
        ),
        struct(
            msg = "restrict to repos, not found",
            module = "Foo",
            preferred = None,
            restrict_to = ["some_other_repo"],
            exp = None,
        ),
        struct(
            msg = "preferred repo and restrict to repos, found preferred",
            module = "Foo",
            preferred = "example_cool_repo",
            restrict_to = ["example_cool_repo", "example_another_repo"],
            exp = bazel_labels.new(
                repository_name = "@example_cool_repo",
                package = "",
                name = "Foo",
            ),
        ),
    ]
    for t in tests:
        actual = deps_indexes.resolve_module(
            _deps_index,
            module_name = t.module,
            preferred_repo_name = t.preferred,
            restrict_to_repo_names = t.restrict_to,
        )
        actual_label = actual.label if actual else None
        asserts.equals(env, t.exp, actual_label, t.msg)

    return unittest.end(env)

resolve_module_test = unittest.make(_resolve_module_test)

def _resolve_module_with_ctx_test(ctx):
    env = unittest.begin(ctx)

    deps_index_ctx = deps_indexes.new_ctx(
        deps_index = _deps_index,
        preferred_repo_name = "example_cool_repo",
        restrict_to_repo_names = ["example_cool_repo", "example_another_repo"],
    )
    actual = deps_indexes.resolve_module_with_ctx(
        deps_index_ctx = deps_index_ctx,
        module_name = "Foo",
    )
    exp_label = bazel_labels.parse("@example_cool_repo//:Foo")
    asserts.equals(env, exp_label, actual.label)

    return unittest.end(env)

resolve_module_with_ctx_test = unittest.make(_resolve_module_with_ctx_test)

def _labels_for_module_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "Swift depend upon Swift",
            dep_module = "@example_cool_repo//:Foo",
            depender_module = "@example_cool_repo//:Bar",
            exp = [
                bazel_labels.parse("@example_cool_repo//:Foo"),
            ],
        ),
        struct(
            msg = "Swift library depends upon Objc library",
            dep_module = "@example_cool_repo//:ObjcLibrary",
            depender_module = "@example_cool_repo//:Bar",
            exp = [
                bazel_labels.parse("@example_cool_repo//:ObjcLibrary"),
                bazel_labels.parse("@example_cool_repo//:ObjcLibrary_modulemap"),
            ],
        ),
        struct(
            msg = "Objc library depends upon Swift library without modulemap",
            dep_module = "@example_cool_repo//:Foo",
            depender_module = "@example_cool_repo//:ObjcLibrary",
            exp = [
                bazel_labels.parse("@example_cool_repo//:Foo"),
                # bazel_labels.parse("@example_cool_repo//:Foo_modulemap"),
            ],
        ),
        struct(
            msg = "Objc library depends upon Swift library with modulemap",
            dep_module = "@example_another_repo//Sources/Foo",
            depender_module = "@example_cool_repo//:ObjcLibrary",
            exp = [
                bazel_labels.parse("@example_another_repo//Sources/Foo"),
                bazel_labels.parse("@example_another_repo//Sources/Foo:Foo_modulemap"),
            ],
        ),
    ]
    for t in tests:
        module = deps_indexes.get_module(_deps_index, t.dep_module)
        depender = deps_indexes.get_module(_deps_index, t.depender_module)
        if module == None:
            fail("The module is `None` for {}.".format(t.label))
        if depender == None:
            fail("The depender module is `None` for {}.".format(t.depender_label))
        actual = deps_indexes.labels_for_module(module, depender.src_type)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

labels_for_module_test = unittest.make(_labels_for_module_test)

def _resolve_product_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "ArgumentParser product",
            product = "ArgumentParser",
            preferred = None,
            restrict_to = [],
            exp = deps_indexes.new_product_index_key(
                "swift-argument-parser",
                "ArgumentParser",
            ),
        ),
        struct(
            msg = "product not in index",
            product = "DoesNotExist",
            preferred = None,
            restrict_to = [],
            exp = None,
        ),
        struct(
            msg = "preferred repo name exists",
            product = "Foo",
            preferred = "example_cool_repo",
            restrict_to = [],
            exp = deps_indexes.new_product_index_key(
                "example-cool-repo",
                "Foo",
            ),
        ),
        struct(
            msg = "preferred repo name not found",
            product = "ArgumentParser",
            preferred = "example_another_repo",
            restrict_to = [],
            exp = deps_indexes.new_product_index_key(
                "swift-argument-parser",
                "ArgumentParser",
            ),
        ),
        struct(
            msg = "restrict to repos, found one",
            product = "Foo",
            preferred = None,
            restrict_to = ["some_other_repo", "example_another_repo"],
            exp = deps_indexes.new_product_index_key(
                "example-another-repo",
                "Foo",
            ),
        ),
        struct(
            msg = "restrict to repos, not found",
            product = "Foo",
            preferred = None,
            restrict_to = ["some_other_repo"],
            exp = None,
        ),
        struct(
            msg = "preferred repo and restrict to repos, found preferred",
            product = "Foo",
            preferred = "example_cool_repo",
            restrict_to = ["example_cool_repo", "example_another_repo"],
            exp = deps_indexes.new_product_index_key(
                "example-cool-repo",
                "Foo",
            ),
        ),
    ]
    for t in tests:
        actual = deps_indexes.resolve_product(
            _deps_index,
            product_name = t.product,
            preferred_repo_name = t.preferred,
            restrict_to_repo_names = t.restrict_to,
        )
        actual_key = deps_indexes.new_product_index_key_for_product(actual)
        asserts.equals(env, t.exp, actual_key, t.msg)

    return unittest.end(env)

resolve_product_test = unittest.make(_resolve_product_test)

def _resolve_product_with_ctx_test(ctx):
    env = unittest.begin(ctx)

    deps_index_ctx = deps_indexes.new_ctx(
        deps_index = _deps_index,
        preferred_repo_name = "example_cool_repo",
        restrict_to_repo_names = ["example_cool_repo", "example_another_repo"],
    )
    actual = deps_indexes.resolve_product_with_ctx(
        deps_index_ctx = deps_index_ctx,
        product_name = "Foo",
    )
    exp_key = deps_indexes.new_product_index_key("example-cool-repo", "Foo")
    actual_key = deps_indexes.new_product_index_key_for_product(actual)
    asserts.equals(env, exp_key, actual_key)

    return unittest.end(env)

resolve_product_with_ctx_test = unittest.make(_resolve_product_with_ctx_test)

def _new_module_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "no modulemap_label",
            modulemap_label = None,
        ),
        struct(
            msg = "with modulemap_label",
            modulemap_label = bazel_labels.parse(
                "@example_cool_repo//:Foo_modulemap",
            ),
        ),
    ]
    for t in tests:
        actual = deps_indexes.new_module(
            name = "Foo",
            c99name = "Foo",
            src_type = src_types.swift,
            label = bazel_labels.parse("@example_cool_repo//:Foo"),
            package_identity = "example_cool_repo",
            product_memberships = ["Bar"],
            modulemap_label = t.modulemap_label,
        )
        asserts.equals(env, "Foo", actual.name, t.msg)
        asserts.equals(env, "Foo", actual.c99name, t.msg)
        asserts.equals(env, src_types.swift, actual.src_type, t.msg)
        asserts.equals(
            env,
            bazel_labels.parse("@example_cool_repo//:Foo"),
            actual.label,
            t.msg,
        )
        asserts.equals(env, "example_cool_repo", actual.package_identity, t.msg)
        asserts.equals(env, ["Bar"], actual.product_memberships, t.msg)
        asserts.equals(env, t.modulemap_label, actual.modulemap_label, t.msg)

    return unittest.end(env)

new_module_test = unittest.make(_new_module_test)

def deps_indexes_test_suite():
    return unittest.suite(
        "deps_indexes_tests",
        new_from_json_test,
        get_module_test,
        resolve_module_test,
        resolve_module_with_ctx_test,
        resolve_product_test,
        resolve_product_with_ctx_test,
        labels_for_module_test,
        new_module_test,
    )

_deps_index_json = """
{
    "modules": [
        {
            "name": "ArgumentParser",
            "c99name": "ArgumentParser",
            "src_type": "swift",
            "label": "@apple_swift_argument_parser//Sources/ArgumentParser",
            "package_identity": "swift-argument-parser",
            "product_memberships": ["ArgumentParser"]
        },
        {
            "name": "Foo",
            "c99name": "Foo",
            "src_type": "swift",
            "label": "@example_cool_repo//:Foo",
            "package_identity": "example-cool-repo",
            "product_memberships": ["Foo"]
        },
        {
            "name": "Foo",
            "c99name": "Foo",
            "src_type": "swift",
            "label": "@example_another_repo//Sources/Foo",
            "modulemap_label": "@example_another_repo//Sources/Foo:Foo_modulemap",
            "package_identity": "example-another-repo",
            "product_memberships": ["Foo"]
        },
        {
            "name": "Bar",
            "c99name": "Bar",
            "src_type": "swift",
            "label": "@example_cool_repo//:Bar",
            "package_identity": "example-cool-repo",
            "product_memberships": ["Foo"]
        },
        {
            "name": "Bar",
            "c99name": "Bar",
            "src_type": "swift",
            "label": "@example_another_repo//Sources/Bar",
            "package_identity": "example-another-repo",
            "product_memberships": ["Foo"]
        },
        {
            "name": "ObjcLibrary",
            "c99name": "ObjcLibrary",
            "src_type": "objc",
            "label": "@example_cool_repo//:ObjcLibrary",
            "package_identity": "example-cool-repo",
            "product_memberships": ["Foo"]
        }
    ],
    "products": [
        {
            "identity": "swift-argument-parser",
            "name": "ArgumentParser",
            "type": "library",
            "label": "@apple_swift_argument_parser//ArgumentParser"
        },
        {
            "identity": "example-cool-repo",
            "name": "Foo",
            "type": "library",
            "label": "@example_cool_repo//:Foo"
        },
        {
            "identity": "example-another-repo",
            "name": "Foo",
            "type": "library",
            "label": "@example_another_repo//Sources/Foo"
        }
    ],
    "packages": [
        {
            "name": "swiftpkg_swift_argument_parser",
            "identity": "swift-argument-parser",
            "remote": {
                "commit": "4ad606ba5d7673ea60679a61ff867cc1ff8c8e86",
                "remote": "https://github.com/apple/swift-argument-parser",
                "version": "1.2.1"
            }
        },
        {
            "name": "swiftpkg_example_cool_repo",
            "identity": "example-cool-repo",
            "local": {
                "path": "third_party/example_cool_repo"
            }
        },
        {
            "name": "swiftpkg_example_another_repo",
            "identity": "example-another-repo",
            "local": {
                "path": "third_party/example_another_repo"
            }
        }
    ]
}
"""

_deps_index = deps_indexes.new_from_json(_deps_index_json)
