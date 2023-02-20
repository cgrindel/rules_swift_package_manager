"""Tests for `swiftpkg_bld_decls` module."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
load(
    "//config_settings/spm/configuration:configurations.bzl",
    spm_configurations = "configurations",
)
load(
    "//config_settings/spm/platform:platforms.bzl",
    spm_platforms = "platforms",
)
load("//swiftpkg/internal:pkg_ctxs.bzl", "pkg_ctxs")
load("//swiftpkg/internal:pkginfo_targets.bzl", "pkginfo_targets")
load(
    "//swiftpkg/internal:pkginfos.bzl",
    "build_setting_kinds",
    "library_type_kinds",
    "pkginfos",
)
load("//swiftpkg/internal:starlark_codegen.bzl", scg = "starlark_codegen")
load(
    "//swiftpkg/internal:swiftpkg_build_files.bzl",
    "swiftpkg_build_files",
)

# MARK: - Repository CTX Stub

def new_exec_result(return_code = 0, stdout = "", stderr = ""):
    return struct(
        return_code = return_code,
        stdout = stdout,
        stderr = stderr,
    )

def new_stub_repository_ctx(repo_name, file_contents = {}, find_results = {}):
    def read(path):
        return file_contents.get(path, "")

    # buildifier: disable=unused-variable
    def execute(args, quiet = True):
        # The find command that we expect is `find -H -L path`.
        # See repository_files.list_files_under for details.
        if len(args) >= 4 and args[0] == "find":
            path = args[3]
            results = find_results.get(path, [])
            exec_result = new_exec_result(
                stdout = "\n".join(results),
            )
        else:
            exec_result = new_exec_result()
        return exec_result

    return struct(
        name = repo_name,
        read = read,
        execute = execute,
    )

# MARK: - Test Data

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
            swift_settings = pkginfos.new_swift_settings([
                pkginfos.new_build_setting(
                    kind = build_setting_kinds.define,
                    values = ["FOOBAR"],
                    condition = pkginfos.new_build_setting_condition(
                        platforms = [
                            spm_platforms.ios,
                            spm_platforms.tvos,
                        ],
                    ),
                ),
                pkginfos.new_build_setting(
                    kind = build_setting_kinds.unsafe_flags,
                    values = ["-cross-module-optimization"],
                    condition = pkginfos.new_build_setting_condition(
                        configuration = spm_configurations.release,
                    ),
                ),
            ]),
        ),
        pkginfos.new_target(
            name = "SwiftLibraryUsesXCTest",
            type = "regular",
            c99name = "SwiftLibraryUsesXCTest",
            module_type = "SwiftTarget",
            path = "Source/SwiftLibraryUsesXCTest",
            sources = [
                "SwiftLibraryUsesXCTest.swift",
            ],
            dependencies = [],
        ),
        pkginfos.new_target(
            name = "ClangLibrary",
            type = "regular",
            c99name = "ClangLibrary",
            module_type = "ClangTarget",
            path = ".",
            # NOTE: SPM does not report header files in the sources for clang
            # targets. The `swift_package` code reads the filesystem to find
            # the sources.
            sources = [
                "src/foo.cc",
            ],
            source_paths = [
                "src/",
            ],
            exclude_paths = [
                "src/do_not_include_me.cc",
            ],
            public_hdrs_path = "include",
            dependencies = [],
            clang_settings = pkginfos.new_clang_settings([
                pkginfos.new_build_setting(
                    kind = build_setting_kinds.define,
                    values = ["PLATFORM_POSIX=1"],
                ),
                pkginfos.new_build_setting(
                    kind = build_setting_kinds.header_search_path,
                    values = ["./"],
                ),
                pkginfos.new_build_setting(
                    kind = build_setting_kinds.unsafe_flags,
                    values = ["-danger"],
                    condition = pkginfos.new_build_setting_condition(
                        configuration = spm_configurations.release,
                    ),
                ),
            ]),
        ),
        pkginfos.new_target(
            name = "ObjcLibraryDep",
            type = "regular",
            c99name = "ObjcLibraryDep",
            module_type = "ClangTarget",
            path = ".",
            sources = [
                "objc_dep/foo.m",
                "objc_dep/foo.h",
            ],
            source_paths = [
                "objc_dep/",
            ],
            public_hdrs_path = "include",
            dependencies = [],
        ),
        pkginfos.new_target(
            name = "ObjcLibrary",
            type = "regular",
            c99name = "ObjcLibrary",
            module_type = "ClangTarget",
            path = ".",
            # NOTE: SPM does not report header files in the sources for clang
            # targets. The `swift_package` code reads the filesystem to find
            # the sources.
            sources = [
                "src/foo.m",
                "src/foo.h",
            ],
            source_paths = [
                "src/",
            ],
            public_hdrs_path = "include",
            dependencies = [
                pkginfos.new_target_dependency(
                    by_name = pkginfos.new_by_name_reference("ObjcLibraryDep"),
                ),
            ],
        ),
        pkginfos.new_target(
            name = "SwiftLibraryWithConditionalDep",
            type = "regular",
            c99name = "SwiftLibraryWithConditionalDep",
            module_type = "SwiftTarget",
            path = "Source/SwiftLibraryWithConditionalDep",
            sources = [
                "SwiftLibraryWithConditionalDep.swift",
            ],
            dependencies = [
                pkginfos.new_target_dependency(
                    by_name = pkginfos.new_by_name_reference("ClangLibrary"),
                ),
                pkginfos.new_target_dependency(
                    by_name = pkginfos.new_by_name_reference(
                        "RegularSwiftTargetAsLibrary",
                        condition = pkginfos.new_target_dependency_condition(
                            platforms = ["ios", "tvos"],
                        ),
                    ),
                ),
            ],
        ),
        pkginfos.new_target(
            name = "ClangLibraryWithConditionalDep",
            type = "regular",
            c99name = "SwiftLibraryWithConditionalDep",
            module_type = "ClangTarget",
            path = ".",
            # NOTE: SPM does not report header files in the sources for clang
            # targets. The `swift_package` code reads the filesystem to find
            # the sources.
            sources = [
                "src/foo.cc",
            ],
            source_paths = [
                "src/",
            ],
            public_hdrs_path = "include",
            dependencies = [
                pkginfos.new_target_dependency(
                    by_name = pkginfos.new_by_name_reference(
                        "ClangLibrary",
                        condition = pkginfos.new_target_dependency_condition(
                            platforms = ["ios", "tvos"],
                        ),
                    ),
                ),
            ],
        ),
        pkginfos.new_target(
            name = "SwiftForObjcTarget",
            type = "regular",
            c99name = "SwiftForObjcTarget",
            module_type = "SwiftTarget",
            path = "Source/SwiftForObjcTarget",
            sources = [
                "SwiftForObjcTarget.swift",
            ],
            dependencies = [
                pkginfos.new_target_dependency(
                    by_name = pkginfos.new_by_name_reference("ObjcLibraryDep"),
                ),
            ],
        ),
    ],
)

_deps_index_json = """
{
  "modules": [
    {"name": "RegularTargetForExec", "c99name": "RegularTargetForExec", "src_type": "swift", "label": "@swiftpkg_mypackage//:Source_RegularTargetForExec"},
    {"name": "RegularSwiftTargetAsLibrary", "c99name": "RegularSwiftTargetAsLibrary", "src_type": "swift", "label": "@swiftpkg_mypackage//:Source_RegularSwiftTargetAsLibrary"},
    {"name": "RegularSwiftTargetAsLibraryTests", "c99name": "RegularSwiftTargetAsLibraryTests", "src_type": "swift", "label": "@swiftpkg_mypackage//:Source_RegularSwiftTargetAsLibraryTests"},
    {"name": "SwiftExecutableTarget", "c99name": "SwiftExecutableTarget", "src_type": "swift", "label": "@swiftpkg_mypackage//:Source_SwiftLibraryTarget"},
    {"name": "ClangLibrary", "c99name": "ClangLibrary", "src_type": "clang", "label": "@swiftpkg_mypackage//:ClangLibrary"},
    {"name": "ObjcLibrary", "c99name": "ObjcLibrary", "src_type": "objc", "label": "@swiftpkg_mypackage//:ObjcLibrary"},
    {"name": "ObjcLibraryDep", "c99name": "ObjcLibraryDep", "src_type": "objc", "label": "@swiftpkg_mypackage//:ObjcLibraryDep"}
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

# MARK: - Tests

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
    copts = select({
        "@cgrindel_swift_bazel//config_settings/spm/configuration:release": ["-cross-module-optimization"],
        "//conditions:default": [],
    }),
    defines = ["SWIFT_PACKAGE"] + select({
        "@cgrindel_swift_bazel//config_settings/spm/platform:ios": ["FOOBAR"],
        "@cgrindel_swift_bazel//config_settings/spm/platform:tvos": ["FOOBAR"],
        "//conditions:default": [],
    }),
    deps = [],
    module_name = "SwiftExecutableTarget",
    srcs = ["Source/SwiftExecutableTarget/main.swift"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Swift library that uses XCTest should have testonly = True",
            name = "SwiftLibraryUsesXCTest",
            file_contents = {
                "SwiftLibraryUsesXCTest.swift": """\
import XCTest
""",
            },
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Source_SwiftLibraryUsesXCTest",
    defines = ["SWIFT_PACKAGE"],
    deps = [],
    module_name = "SwiftLibraryUsesXCTest",
    srcs = ["Source/SwiftLibraryUsesXCTest/SwiftLibraryUsesXCTest.swift"],
    testonly = True,
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "simple clang target",
            name = "ClangLibrary",
            find_results = {
                "include": [
                    "external.h",
                ],
                "src": [
                    "foo.cc",
                    "foo.h",
                    "do_not_include_me.cc",
                ],
            },
            exp = """\

cc_library(
    name = "ClangLibrary",
    copts = [
        "-fblocks",
        "-fobjc-arc",
        "-fPIC",
        "-fmodule-name=ClangLibrary",
        "-Iexternal/swiftpkg_mypackage/src",
        "-Iexternal/swiftpkg_mypackage",
    ] + select({
        "@cgrindel_swift_bazel//config_settings/spm/configuration:release": ["-danger"],
        "//conditions:default": [],
    }),
    defines = [
        "SWIFT_PACKAGE=1",
        "PLATFORM_POSIX=1",
    ],
    deps = [],
    hdrs = ["include/external.h"],
    includes = ["include"],
    srcs = [
        "src/foo.cc",
        "src/foo.h",
    ],
    tags = ["swift_module=ClangLibrary"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Objc target",
            name = "ObjcLibrary",
            find_results = {
                "include": [
                    "external.h",
                ],
                "src": [
                    "foo.m",
                    "foo.h",
                ],
            },
            exp = """\
load("@cgrindel_swift_bazel//swiftpkg:build_defs.bzl", "generate_modulemap")

objc_library(
    name = "ObjcLibrary",
    copts = [
        "-fblocks",
        "-fobjc-arc",
        "-fPIC",
        "-fmodule-name=ObjcLibrary",
        "-Iexternal/swiftpkg_mypackage/src",
    ],
    defines = ["SWIFT_PACKAGE=1"],
    deps = [
        "@swiftpkg_mypackage//:ObjcLibraryDep",
        "@swiftpkg_mypackage//:ObjcLibraryDep_modulemap",
    ],
    enable_modules = True,
    hdrs = ["include/external.h"],
    includes = ["include"],
    module_name = "ObjcLibrary",
    srcs = [
        "src/foo.h",
        "src/foo.m",
    ],
    tags = ["swift_module=ObjcLibrary"],
    visibility = ["//visibility:public"],
)

generate_modulemap(
    name = "ObjcLibrary_modulemap",
    deps = ["@swiftpkg_mypackage//:ObjcLibraryDep_modulemap"],
    hdrs = ["include/external.h"],
    module_name = "ObjcLibrary",
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Swift target with conditional dep",
            name = "SwiftLibraryWithConditionalDep",
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Source_SwiftLibraryWithConditionalDep",
    defines = ["SWIFT_PACKAGE"],
    deps = ["@swiftpkg_mypackage//:ClangLibrary"] + select({
        "@cgrindel_swift_bazel//config_settings/spm/platform:ios": ["@swiftpkg_mypackage//:Source_RegularSwiftTargetAsLibrary"],
        "@cgrindel_swift_bazel//config_settings/spm/platform:tvos": ["@swiftpkg_mypackage//:Source_RegularSwiftTargetAsLibrary"],
        "//conditions:default": [],
    }),
    module_name = "SwiftLibraryWithConditionalDep",
    srcs = ["Source/SwiftLibraryWithConditionalDep/SwiftLibraryWithConditionalDep.swift"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Clang target with conditional dep",
            name = "ClangLibraryWithConditionalDep",
            find_results = {
                "include": [
                    "external.h",
                ],
                "src": [
                    "foo.cc",
                    "foo.h",
                ],
            },
            exp = """\

cc_library(
    name = "ClangLibraryWithConditionalDep",
    copts = [
        "-fblocks",
        "-fobjc-arc",
        "-fPIC",
        "-fmodule-name=SwiftLibraryWithConditionalDep",
        "-Iexternal/swiftpkg_mypackage/src",
    ],
    defines = ["SWIFT_PACKAGE=1"],
    deps = select({
        "@cgrindel_swift_bazel//config_settings/spm/platform:ios": ["@swiftpkg_mypackage//:ClangLibrary"],
        "@cgrindel_swift_bazel//config_settings/spm/platform:tvos": ["@swiftpkg_mypackage//:ClangLibrary"],
        "//conditions:default": [],
    }),
    hdrs = ["include/external.h"],
    includes = ["include"],
    srcs = [
        "src/foo.cc",
        "src/foo.h",
    ],
    tags = ["swift_module=SwiftLibraryWithConditionalDep"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Swift library target with @objc directives and Objc dep",
            name = "SwiftForObjcTarget",
            file_contents = {
                "SwiftForObjcTarget.swift": """\
import Foundation

@objc(OIFooBar)
public class FooBar: NSObject {
    @objc public func doSomething() {
        // Intentionally blank
    }
}
""",
            },
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@cgrindel_swift_bazel//swiftpkg:build_defs.bzl", "generate_modulemap")

swift_library(
    name = "Source_SwiftForObjcTarget",
    defines = ["SWIFT_PACKAGE"],
    deps = [
        "@swiftpkg_mypackage//:ObjcLibraryDep",
        "@swiftpkg_mypackage//:ObjcLibraryDep_modulemap",
    ],
    generates_header = True,
    module_name = "SwiftForObjcTarget",
    srcs = ["Source/SwiftForObjcTarget/SwiftForObjcTarget.swift"],
    visibility = ["//visibility:public"],
)

generate_modulemap(
    name = "Source_SwiftForObjcTarget_modulemap",
    deps = ["@swiftpkg_mypackage//:ObjcLibraryDep_modulemap"],
    hdrs = [":Source_SwiftForObjcTarget"],
    module_name = "SwiftForObjcTarget",
    visibility = ["//visibility:public"],
)
""",
        ),
    ]
    for t in tests:
        target = pkginfo_targets.get(_pkg_info.targets, t.name)
        repository_ctx = new_stub_repository_ctx(
            repo_name = _repo_name[1:],
            file_contents = {
                paths.normalize(paths.join(_pkg_info.path, target.path, fname)): cnts
                for fname, cnts in getattr(t, "file_contents", {}).items()
            },
            find_results = {
                paths.normalize(paths.join(_pkg_info.path, dirname)): [
                    paths.normalize(paths.join(_pkg_info.path, dirname, fp))
                    for fp in file_paths
                ]
                for dirname, file_paths in getattr(t, "find_results", {}).items()
            },
        )
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
