"""Tests for `swiftpkg_bld_decls` module."""

load("@bazel_skylib//lib:unittest.bzl", "unittest")
load("//swiftpkg/internal:build_files.bzl", "build_files")
load("//swiftpkg/internal:package_infos.bzl", "package_infos")
load("//swiftpkg/internal:swiftpkg_build_files.bzl", "swiftpkg_build_files")

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

def _new_test(ctx):
    env = unittest.begin(ctx)

    build_file = swiftpkg_build_files.new(_pkg_info)

    decl = build_files.find_decl(build_file, "SwiftLintFramework")
    if decl == None:
        unittest.fail(env, "Expected to find SwiftLintFramework declaration.")

    # # DEBUG BEGIN
    # print("*** CHUCK decl: ", decl)
    # # DEBUG END

    # unittest.fail(env, "STOP")

    return unittest.end(env)

new_test = unittest.make(_new_test)

def swiftpkg_build_files_test_suite():
    return unittest.suite(
        "swiftpkg_build_files_tests",
        new_test,
    )
