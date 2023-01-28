"""Tests for `swiftpkg_bld_decls` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
load("//swiftpkg/internal:pkg_ctxs.bzl", "pkg_ctxs")
load("//swiftpkg/internal:pkginfo_targets.bzl", "pkginfo_targets")
load("//swiftpkg/internal:pkginfos.bzl", "library_type_kinds", "pkginfos")
load("//swiftpkg/internal:starlark_codegen.bzl", scg = "starlark_codegen")
load(
    "//swiftpkg/internal:swiftpkg_build_files.bzl",
    "swiftpkg_build_files",
)

_pkg_info = pkginfos.new(
    name = "SwiftLint",
    path = "/path/to/swiftlint",
    dependencies = [
        pkginfos.new_dependency(
            identity = "swift-argument-parser",
            name = "SwiftArgumentParser",
            type = "sourceControl",
            url = "https://github.com/apple/swift-argument-parser.git",
            requirement = pkginfos.new_dependency_requirement(
                ranges = [
                    pkginfos.new_version_range("0.3.1", "0.4.0"),
                ],
            ),
        ),
    ],
    products = [
        pkginfos.new_product(
            name = "swiftlint",
            type = pkginfos.new_product_type(executable = True),
            targets = ["swiftlint"],
        ),
        pkginfos.new_product(
            name = "SwiftLintFramework",
            type = pkginfos.new_product_type(
                library = pkginfos.new_library_type(
                    library_type_kinds.automatic,
                ),
            ),
            targets = ["SwiftLintFramework"],
        ),
    ],
    targets = [
        # Old-style regular library that is used to create a binary from an
        # executable product.
        pkginfos.new_target(
            name = "swiftlint",
            type = "regular",
            c99name = "swiftlint",
            module_type = "SwiftTarget",
            path = "Source/swiftlint",
            sources = [
                "Commands/SwiftLint.swift",
                "main.swift",
            ],
            dependencies = [
                pkginfos.new_target_dependency(
                    by_name = pkginfos.new_by_name_reference(
                        "SwiftLintFramework",
                    ),
                ),
            ],
        ),
        pkginfos.new_target(
            name = "SwiftLintFramework",
            type = "regular",
            c99name = "SwiftLintFramework",
            module_type = "SwiftTarget",
            path = "Source/SwiftLintFramework",
            sources = [
                "SwiftLintFramework.swift",
            ],
            dependencies = [],
        ),
        pkginfos.new_target(
            name = "SwiftLintFrameworkTests",
            type = "test",
            c99name = "SwiftLintFrameworkTests",
            module_type = "SwiftTarget",
            path = "Tests/SwiftLintFrameworkTests",
            sources = [
                "SwiftLintFrameworkTests.swift",
            ],
            dependencies = [
                pkginfos.new_target_dependency(
                    by_name = pkginfos.new_by_name_reference(
                        "SwiftLintFramework",
                    ),
                ),
            ],
        ),
    ],
)

_deps_index_json = """
{
  "modules": [
    {"name": "swiftlint", "c99name": "swiftlint", "label": "@swiftpkg_swiftlint//:Source_swiftlint"},
    {"name": "SwiftLintFramework", "c99name": "SwiftLintFramework", "label": "@swiftpkg_swiftlint//:Source_SwiftLintFramework"},
    {"name": "SwiftLintFrameworkTests", "c99name": "SwiftLintFrameworkTests", "label": "@swiftpkg_swiftlint//:Source_SwiftLintFrameworkTests"}
  ],
  "products": [
  ]
}
"""

_repo_name = "@swiftpkg_swiftlint"

_pkg_ctx = pkg_ctxs.new(
    pkg_info = _pkg_info,
    repo_name = _repo_name,
    deps_index_json = _deps_index_json,
)

def new_stub_repository_ctx():
    # buildifier: disable=unused-variable
    def read(path):
        return ""

    return struct(
        read = read,
    )

repository_ctx = new_stub_repository_ctx()

def _target_generation_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "Swift library target",
            name = "SwiftLintFramework",
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Source_SwiftLintFramework",
    defines = ["SWIFT_PACKAGE"],
    deps = [],
    module_name = "SwiftLintFramework",
    srcs = ["Source/SwiftLintFramework/SwiftLintFramework.swift"],
    visibility = ["//visibility:public"],
)
""",
        ),
        # The swiftlint target is an older style executable definition (regular).
        # We create the swift_library in the target package. Then, we create the
        # executable when defining the product.
        struct(
            msg = "Swift regular target associated with executable product",
            name = "swiftlint",
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Source_swiftlint",
    defines = ["SWIFT_PACKAGE"],
    deps = ["@swiftpkg_swiftlint//:Source_SwiftLintFramework"],
    module_name = "swiftlint",
    srcs = [
        "Source/swiftlint/Commands/SwiftLint.swift",
        "Source/swiftlint/main.swift",
    ],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Swift test target",
            name = "SwiftLintFrameworkTests",
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_test")

swift_test(
    name = "Tests_SwiftLintFrameworkTests",
    defines = ["SWIFT_PACKAGE"],
    deps = ["@swiftpkg_swiftlint//:Source_SwiftLintFramework"],
    module_name = "SwiftLintFrameworkTests",
    srcs = ["Tests/SwiftLintFrameworkTests/SwiftLintFrameworkTests.swift"],
    visibility = ["//visibility:public"],
)
""",
        ),
    ]
    for t in tests:
        target = pkginfo_targets.get(_pkg_info.targets, t.name)
        actual = scg.to_starlark(
            swiftpkg_build_files.new_for_target(repository_ctx, _pkg_ctx, target),
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

target_generation_test = unittest.make(_target_generation_test)

def _product_generation_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "executable product referencing a regular target (old-style)",
            name = "swiftlint",
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_binary")

swift_binary(
    name = "swiftlint",
    deps = ["@swiftpkg_swiftlint//:Source_swiftlint"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Swift library product",
            name = "SwiftLintFramework",
            exp = """\
load("@bazel_skylib//rules:build_test.bzl", "build_test")

build_test(
    name = "SwiftLintFrameworkBuildTest",
    targets = ["@swiftpkg_swiftlint//:Source_SwiftLintFramework"],
    visibility = ["//visibility:public"],
)
""",
        ),
    ]
    for t in tests:
        product = lists.find(_pkg_info.products, lambda p: p.name == t.name)
        actual = scg.to_starlark(
            swiftpkg_build_files.new_for_product(
                pkg_info = _pkg_ctx.pkg_info,
                product = product,
                repo_name = _pkg_ctx.repo_name,
            ),
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

product_generation_test = unittest.make(_product_generation_test)

def swiftpkg_build_files_test_suite():
    return unittest.suite(
        "swiftpkg_build_files_tests",
        target_generation_test,
        product_generation_test,
    )
