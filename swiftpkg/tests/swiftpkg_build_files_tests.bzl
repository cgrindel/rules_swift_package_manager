"""Tests for `swiftpkg_bld_decls` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:package_infos.bzl", "package_infos")
load("//swiftpkg/internal:pkginfo_targets.bzl", "pkginfo_targets")
load("//swiftpkg/internal:swiftpkg_build_files.bzl", "swift_kinds", "swift_library_load_stmt", "swiftpkg_build_files")

# This is a simplified version of SwiftLint.
_pkg_info = package_infos.new(
    name = "SwiftLint",
    path = "/path/to/swiftlint",
    dependencies = [
        package_infos.new_dependency(
            identity = "swift-argument-parser",
            type = "sourceControl",
            url = "https://github.com/apple/swift-argument-parser.git",
            requirement = package_infos.new_dependency_requirement(
                ranges = [
                    package_infos.new_version_range("0.3.1", "0.4.0"),
                ],
            ),
        ),
    ],
    products = [
        package_infos.new_product(
            name = "swiftlint",
            type = package_infos.new_product_type(executable = True),
            targets = ["swiftlint"],
        ),
    ],
    targets = [
        package_infos.new_target(
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
                package_infos.new_target_dependency(
                    by_name = package_infos.new_target_reference(
                        "SwiftLintFramework",
                    ),
                ),
            ],
        ),
        package_infos.new_target(
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
        package_infos.new_target(
            name = "SwiftLintFrameworkTests",
            type = "regular",
            c99name = "SwiftLintFrameworkTests",
            module_type = "SwiftTarget",
            path = "Tests/SwiftLintFrameworkTests",
            sources = [
                "SwiftLintFrameworkTests.swift",
            ],
            dependencies = [
                package_infos.new_target_dependency(
                    by_name = package_infos.new_target_reference(
                        "SwiftLintFramework",
                    ),
                ),
            ],
        ),
    ],
)

def _new_for_targets_test(ctx):
    env = unittest.begin(ctx)

    target = pkginfo_targets.get(_pkg_info.targets, "SwiftLintFramework")
    build_file = swiftpkg_build_files.new_for_target(_pkg_info, target)
    asserts.equals(env, 1, len(build_file.decls))
    decl = build_decls.get(build_file.decls, "SwiftLintFramework")
    asserts.false(env, decl == None)
    expected = build_decls.new(
        kind = swift_kinds.library,
        name = "SwiftLintFramework",
        attrs = {
            "deps": [],
            "module_name": "SwiftLintFramework",
            "srcs": [
                "SwiftLintFramework.swift",
            ],
            "visibility": ["//visibility:public"],
        },
    )
    # asserts.equals(env, swift_kinds.library, decl.kind)

    # The swiftlint target is an older style executable definition (regular).
    # We create the swift_library in the target package. Then, we create the
    # executable when defining the product.
    target = pkginfo_targets.get(_pkg_info.targets, "swiftlint")
    build_file = swiftpkg_build_files.new_for_target(_pkg_info, target)
    expected_load_stmts = [swift_library_load_stmt]
    asserts.equals(env, expected_load_stmts, build_file.load_stmts)
    asserts.equals(env, 1, len(build_file.decls))
    decl = build_decls.get(build_file.decls, "swiftlint")
    expected = build_decls.new(
        kind = swift_kinds.library,
        name = "swiftlint",
        attrs = {
            "deps": [
                "@//Source/SwiftLintFramework",
            ],
            "module_name": "swiftlint",
            "srcs": [
                "Commands/SwiftLint.swift",
                "main.swift",
            ],
            "visibility": ["//visibility:public"],
        },
    )
    asserts.equals(env, expected, decl)
    # asserts.equals(env, swift_kinds.library, decl.kind)

    return unittest.end(env)

new_for_targets_test = unittest.make(_new_for_targets_test)

def swiftpkg_build_files_test_suite():
    return unittest.suite(
        "swiftpkg_build_files_tests",
        new_for_targets_test,
    )
