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
    name = "MyPackage",
    path = "/path/to/my-package",
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
            name = "oldstyleexec",
            type = pkginfos.new_product_type(executable = True),
            targets = ["RegularTargetForExec"],
        ),
        pkginfos.new_product(
            name = "RegularSwiftTargetAsLibrary",
            type = pkginfos.new_product_type(
                library = pkginfos.new_library_type(
                    library_type_kinds.automatic,
                ),
            ),
            targets = ["RegularSwiftTargetAsLibrary"],
        ),
        pkginfos.new_product(
            name = "swiftexec",
            type = pkginfos.new_product_type(executable = True),
            targets = ["SwiftExecutableTarget"],
        ),
    ],
    targets = [
        # Old-style regular library that is used to create a binary from an
        # executable product.
        pkginfos.new_target(
            name = "RegularTargetForExec",
            type = "regular",
            c99name = "RegularTargetForExec",
            module_type = "SwiftTarget",
            path = "Source/RegularTargetForExec",
            sources = [
                "main.swift",
            ],
            dependencies = [
                pkginfos.new_target_dependency(
                    by_name = pkginfos.new_by_name_reference(
                        "RegularSwiftTargetAsLibrary",
                    ),
                ),
            ],
        ),
        pkginfos.new_target(
            name = "RegularSwiftTargetAsLibrary",
            type = "regular",
            c99name = "RegularSwiftTargetAsLibrary",
            module_type = "SwiftTarget",
            path = "Source/RegularSwiftTargetAsLibrary",
            sources = [
                "RegularSwiftTargetAsLibrary.swift",
            ],
            dependencies = [],
        ),
        pkginfos.new_target(
            name = "RegularSwiftTargetAsLibraryTests",
            type = "test",
            c99name = "RegularSwiftTargetAsLibraryTests",
            module_type = "SwiftTarget",
            path = "Tests/RegularSwiftTargetAsLibraryTests",
            sources = [
                "RegularSwiftTargetAsLibraryTests.swift",
            ],
            dependencies = [
                pkginfos.new_target_dependency(
                    by_name = pkginfos.new_by_name_reference(
                        "RegularSwiftTargetAsLibrary",
                    ),
                ),
            ],
        ),
        pkginfos.new_target(
            name = "SwiftExecutableTarget",
            type = "executable",
            c99name = "SwiftExecutableTarget",
            module_type = "SwiftTarget",
            path = "Source/SwiftExecutableTarget",
            sources = ["main.swift"],
            dependencies = [],
        ),
    ],
)

_deps_index_json = """
{
  "modules": [
    {"name": "RegularTargetForExec", "c99name": "RegularTargetForExec", "label": "@swiftpkg_mypackage//:Source_RegularTargetForExec"},
    {"name": "RegularSwiftTargetAsLibrary", "c99name": "RegularSwiftTargetAsLibrary", "label": "@swiftpkg_mypackage//:Source_RegularSwiftTargetAsLibrary"},
    {"name": "RegularSwiftTargetAsLibraryTests", "c99name": "RegularSwiftTargetAsLibraryTests", "label": "@swiftpkg_mypackage//:Source_RegularSwiftTargetAsLibraryTests"},
    {"name": "SwiftExecutableTarget", "c99name": "SwiftExecutableTarget", "label": "@swiftpkg_mypackage//:Source_SwiftLibraryTarget"}
  ],
  "products": [
  ]
}
"""

_repo_name = "@swiftpkg_mypackage"

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
            name = "RegularSwiftTargetAsLibrary",
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Source_RegularSwiftTargetAsLibrary",
    defines = ["SWIFT_PACKAGE"],
    deps = [],
    module_name = "RegularSwiftTargetAsLibrary",
    srcs = ["Source/RegularSwiftTargetAsLibrary/RegularSwiftTargetAsLibrary.swift"],
    visibility = ["//visibility:public"],
)
""",
        ),
        # The RegularTargetForExec target is an older style executable definition (regular).
        # We create the swift_library in the target package. Then, we create the
        # executable when defining the product.
        struct(
            msg = "Swift regular target associated with executable product",
            name = "RegularTargetForExec",
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Source_RegularTargetForExec",
    defines = ["SWIFT_PACKAGE"],
    deps = ["@swiftpkg_mypackage//:Source_RegularSwiftTargetAsLibrary"],
    module_name = "RegularTargetForExec",
    srcs = ["Source/RegularTargetForExec/main.swift"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Swift test target",
            name = "RegularSwiftTargetAsLibraryTests",
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_test")

swift_test(
    name = "Tests_RegularSwiftTargetAsLibraryTests",
    defines = ["SWIFT_PACKAGE"],
    deps = ["@swiftpkg_mypackage//:Source_RegularSwiftTargetAsLibrary"],
    module_name = "RegularSwiftTargetAsLibraryTests",
    srcs = ["Tests/RegularSwiftTargetAsLibraryTests/RegularSwiftTargetAsLibraryTests.swift"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Swift executable target",
            name = "SwiftExecutableTarget",
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_binary")

swift_binary(
    name = "Source_SwiftExecutableTarget",
    defines = ["SWIFT_PACKAGE"],
    deps = [],
    module_name = "SwiftExecutableTarget",
    srcs = ["Source/SwiftExecutableTarget/main.swift"],
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
            name = "oldstyleexec",
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_binary")

swift_binary(
    name = "oldstyleexec",
    deps = ["@swiftpkg_mypackage//:Source_RegularTargetForExec"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Swift library product",
            name = "RegularSwiftTargetAsLibrary",
            exp = """\
load("@bazel_skylib//rules:build_test.bzl", "build_test")

build_test(
    name = "RegularSwiftTargetAsLibraryBuildTest",
    targets = ["@swiftpkg_mypackage//:Source_RegularSwiftTargetAsLibrary"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Swift exectable product",
            name = "swiftexec",
            exp = """\

alias(
    name = "swiftexec",
    actual = "@swiftpkg_mypackage//:Source_SwiftExecutableTarget",
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
