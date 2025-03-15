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
load(":testutils.bzl", "testutils")

# MARK: - Test Data

_repo_name = "@swiftpkg_mypackage"

def _pkg_info(
        expose_build_targets = False):
    return pkginfos.new(
        name = "MyPackage",
        path = "/path/to/my-package",
        tools_version = "5.9",
        url = "https://github.com/my/package",
        version = "0.4.2",
        dependencies = [
            pkginfos.new_dependency(
                identity = "swift-argument-parser",
                name = "SwiftArgumentParser",
                source_control = pkginfos.new_source_control(
                    pin = pkginfos.new_pin(
                        identity = "swift-argument-parser",
                        kind = "remoteSourceControl",
                        location = "https://github.com/apple/swift-argument-parser",
                        state = pkginfos.new_pin_state(
                            revision = "6c89474e62719ddcc1e9614989fff2f68208fe10",
                            version = "1.0.0",
                        ),
                    ),
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
                name = "ObjcLibraryWithModulemap",
                type = pkginfos.new_product_type(
                    library = pkginfos.new_library_type(
                        library_type_kinds.automatic,
                    ),
                ),
                targets = ["ObjcLibraryWithModulemap"],
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
                repo_name = _repo_name,
                swift_src_info = pkginfos.new_swift_src_info(),
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
                repo_name = _repo_name,
                swift_src_info = pkginfos.new_swift_src_info(),
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
                repo_name = _repo_name,
                swift_src_info = pkginfos.new_swift_src_info(),
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
                        kind = build_setting_kinds.language_modes,
                        values = ["6"],
                    ),
                    pkginfos.new_build_setting(
                        kind = build_setting_kinds.experimental_features,
                        values = ["BuiltinModule"],
                    ),
                    pkginfos.new_build_setting(
                        kind = build_setting_kinds.upcoming_features,
                        values = ["ExistentialAny"],
                    ),
                    pkginfos.new_build_setting(
                        kind = build_setting_kinds.unsafe_flags,
                        values = ["-cross-module-optimization"],
                        condition = pkginfos.new_build_setting_condition(
                            configuration = spm_configurations.release,
                        ),
                    ),
                ]),
                repo_name = _repo_name,
                swift_src_info = pkginfos.new_swift_src_info(),
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
                repo_name = _repo_name,
                clang_src_info = pkginfos.new_clang_src_info(
                    hdrs = ["include/external.h"],
                    srcs = [
                        "src/foo.cc",
                        "src/foo.h",
                    ],
                    public_includes = ["include"],
                    private_includes = ["src"],
                    textual_hdrs = ["src/foo.cc"],
                ),
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
                repo_name = _repo_name,
                clang_src_info = pkginfos.new_clang_src_info(
                    hdrs = ["include/external.h"],
                    srcs = [
                        "src/foo.m",
                        "src/foo.h",
                    ],
                ),
                objc_src_info = pkginfos.new_objc_src_info(),
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
                repo_name = _repo_name,
                clang_src_info = pkginfos.new_clang_src_info(
                    hdrs = ["include/external.h"],
                    srcs = [
                        "src/foo.h",
                        "src/foo.m",
                    ],
                    public_includes = ["include"],
                    private_includes = ["src"],
                    textual_hdrs = ["src/foo.m"],
                ),
                objc_src_info = pkginfos.new_objc_src_info(
                    builtin_frameworks = [
                        "Foundation",
                        "UIKit",
                    ],
                ),
            ),
            pkginfos.new_target(
                name = "ObjcLibraryWithModulemap",
                type = "regular",
                c99name = "ObjcLibraryWithModulemap",
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
                repo_name = _repo_name,
                clang_src_info = pkginfos.new_clang_src_info(
                    hdrs = ["include/external.h"],
                    srcs = [
                        "src/foo.h",
                        "src/foo.m",
                    ],
                    public_includes = ["include"],
                    private_includes = ["src"],
                    textual_hdrs = ["src/foo.m"],
                    modulemap_path = "include/module.modulemap",
                ),
                objc_src_info = pkginfos.new_objc_src_info(
                    builtin_frameworks = [
                        "Foundation",
                        "UIKit",
                    ],
                ),
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
                repo_name = _repo_name,
                swift_src_info = pkginfos.new_swift_src_info(),
            ),
            pkginfos.new_target(
                name = "ClangLibraryWithConditionalDep",
                type = "regular",
                c99name = "ClangLibraryWithConditionalDep",
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
                repo_name = _repo_name,
                clang_src_info = pkginfos.new_clang_src_info(
                    hdrs = ["include/external.h"],
                    srcs = [
                        "src/foo.cc",
                        "src/foo.h",
                    ],
                    public_includes = ["include"],
                    private_includes = ["src"],
                    textual_hdrs = ["src/foo.cc"],
                ),
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
                repo_name = _repo_name,
                swift_src_info = pkginfos.new_swift_src_info(has_objc_directive = True),
            ),
            pkginfos.new_target(
                name = "SwiftLibraryWithFilePathResource",
                type = "regular",
                c99name = "SwiftLibraryWithFilePathResource",
                module_type = "SwiftTarget",
                path = "Source/SwiftLibraryWithFilePathResource",
                sources = [
                    "SwiftLibraryWithFilePathResource.swift",
                ],
                resources = [
                    pkginfos.new_resource(
                        path = "Source/SwiftLibraryWithFilePathResource/Resources/chicken.json",
                        rule = pkginfos.new_resource_rule(
                            process = pkginfos.new_resource_rule_process(),
                        ),
                    ),
                ],
                dependencies = [],
                repo_name = _repo_name,
                swift_src_info = pkginfos.new_swift_src_info(),
            ),
            pkginfos.new_target(
                name = "ObjcLibraryWithResources",
                type = "regular",
                c99name = "ObjcLibraryWithResources",
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
                resources = [
                    pkginfos.new_resource(
                        path = "Source/ObjcLibraryWithResources/Resources/chicken.json",
                        rule = pkginfos.new_resource_rule(
                            process = pkginfos.new_resource_rule_process(),
                        ),
                    ),
                ],
                dependencies = [],
                repo_name = _repo_name,
                clang_src_info = pkginfos.new_clang_src_info(
                    hdrs = ["include/external.h"],
                    srcs = [
                        "src/foo.h",
                        "src/foo.m",
                    ],
                    public_includes = ["include"],
                    private_includes = ["src"],
                    textual_hdrs = ["src/foo.m"],
                ),
                objc_src_info = pkginfos.new_objc_src_info(
                    builtin_frameworks = [
                        "Foundation",
                        "UIKit",
                    ],
                ),
            ),
        ],
        expose_build_targets = expose_build_targets,
    )

def _pkg_ctx(pkg_info):
    return pkg_ctxs.new(
        pkg_info = pkg_info,
        repo_name = _repo_name,
    )

# MARK: - Tests

def _target_generation_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "Swift library target",
            name = "RegularSwiftTargetAsLibrary",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "RegularSwiftTargetAsLibrary.rspm",
    always_include_developer_search_paths = True,
    alwayslink = True,
    copts = [
        "-DSWIFT_PACKAGE",
        "-Xcc",
        "-DSWIFT_PACKAGE",
    ],
    module_name = "RegularSwiftTargetAsLibrary",
    package_name = "MyPackage",
    srcs = ["Source/RegularSwiftTargetAsLibrary/RegularSwiftTargetAsLibrary.swift"],
    tags = ["manual"],
    visibility = ["//:__subpackages__"],
)
""",
        ),
        # The RegularTargetForExec target is an older style executable definition (regular).
        # We create the swift_library in the target package. Then, we create the
        # executable when defining the product.
        struct(
            msg = "Swift regular target associated with executable product",
            name = "RegularTargetForExec",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "RegularTargetForExec.rspm",
    always_include_developer_search_paths = True,
    alwayslink = True,
    copts = [
        "-DSWIFT_PACKAGE",
        "-Xcc",
        "-DSWIFT_PACKAGE",
    ],
    deps = ["@swiftpkg_mypackage//:RegularSwiftTargetAsLibrary.rspm"],
    module_name = "RegularTargetForExec",
    package_name = "MyPackage",
    srcs = ["Source/RegularTargetForExec/main.swift"],
    tags = ["manual"],
    visibility = ["//:__subpackages__"],
)
""",
        ),
        struct(
            msg = "Swift test target",
            name = "RegularSwiftTargetAsLibraryTests",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_test")

swift_test(
    name = "RegularSwiftTargetAsLibraryTests.rspm",
    copts = [
        "-DSWIFT_PACKAGE",
        "-Xcc",
        "-DSWIFT_PACKAGE",
    ],
    deps = ["@swiftpkg_mypackage//:RegularSwiftTargetAsLibrary.rspm"],
    module_name = "RegularSwiftTargetAsLibraryTests",
    package_name = "MyPackage",
    srcs = ["Tests/RegularSwiftTargetAsLibraryTests/RegularSwiftTargetAsLibraryTests.swift"],
    visibility = ["//:__subpackages__"],
)
""",
        ),
        struct(
            msg = "Swift executable target",
            name = "SwiftExecutableTarget",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_binary")

swift_binary(
    name = "SwiftExecutableTarget.rspm",
    copts = [
        "-DSWIFT_PACKAGE",
        "-Xcc",
        "-DSWIFT_PACKAGE",
    ] + select({
        "@rules_swift_package_manager//config_settings/spm/platform:ios": ["-DFOOBAR"],
        "//conditions:default": [],
    }) + select({
        "@rules_swift_package_manager//config_settings/spm/platform:tvos": ["-DFOOBAR"],
        "//conditions:default": [],
    }) + select({
        "@rules_swift_package_manager//config_settings/spm/configuration:release": ["-cross-module-optimization"],
        "//conditions:default": [],
    }),
    features = [
        "swift.enable_v6",
        "swift.experimental.BuiltinModule",
        "swift.upcoming.ExistentialAny",
    ],
    module_name = "SwiftExecutableTarget",
    package_name = "MyPackage",
    srcs = ["Source/SwiftExecutableTarget/main.swift"],
    visibility = ["//:__subpackages__"],
)
""",
        ),
        struct(
            msg = "simple clang target",
            name = "ClangLibrary",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_interop_hint")
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "generate_modulemap")

cc_library(
    name = "ClangLibrary.rspm",
    deps = [
        ":ClangLibrary.rspm_modulemap",
        ":ClangLibrary.rspm_cxx",
    ],
    visibility = ["//:__subpackages__"],
)

cc_library(
    name = "ClangLibrary.rspm_cxx",
    alwayslink = True,
    aspect_hints = ["ClangLibrary.rspm_swift_hint"],
    copts = [
        "-fblocks",
        "-fobjc-arc",
        "-fPIC",
        "-DSWIFT_PACKAGE=1",
        "-fmodule-name=ClangLibrary",
        "-DPLATFORM_POSIX=1",
        "-Iexternal/bzlmodmangled~swiftpkg_mypackage/src",
        "-Iexternal/bzlmodmangled~swiftpkg_mypackage",
    ] + select({
        "@rules_swift_package_manager//config_settings/spm/configuration:release": ["-danger"],
        "//conditions:default": [],
    }),
    hdrs = ["include/external.h"],
    includes = ["include"],
    srcs = [
        "src/foo.cc",
        "src/foo.h",
    ],
    textual_hdrs = ["src/foo.cc"],
    visibility = ["//:__subpackages__"],
)

generate_modulemap(
    name = "ClangLibrary.rspm_modulemap",
    deps = [],
    hdrs = ["include/external.h"],
    module_name = "ClangLibrary",
    visibility = ["//:__subpackages__"],
)

swift_interop_hint(
    name = "ClangLibrary.rspm_swift_hint",
    module_map = "ClangLibrary.rspm_modulemap",
    module_name = "ClangLibrary",
)
""",
        ),
        struct(
            msg = "Objc target",
            name = "ObjcLibrary",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_interop_hint")
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "generate_modulemap")

generate_modulemap(
    name = "ObjcLibrary.rspm_modulemap",
    deps = [],
    hdrs = ["include/external.h"],
    module_name = "ObjcLibrary",
    visibility = ["//:__subpackages__"],
)

objc_library(
    name = "ObjcLibrary.rspm",
    deps = [
        ":ObjcLibrary.rspm_modulemap",
        ":ObjcLibrary.rspm_objc",
    ],
    visibility = ["//:__subpackages__"],
)

objc_library(
    name = "ObjcLibrary.rspm_objc",
    alwayslink = True,
    aspect_hints = ["ObjcLibrary.rspm_swift_hint"],
    copts = [
        "-fblocks",
        "-fobjc-arc",
        "-fPIC",
        "-DSWIFT_PACKAGE=1",
        "-fmodule-name=ObjcLibrary",
        "-Iexternal/bzlmodmangled~swiftpkg_mypackage/src",
    ],
    deps = ["@swiftpkg_mypackage//:ObjcLibraryDep.rspm"],
    enable_modules = True,
    hdrs = ["include/external.h"],
    includes = ["include"],
    sdk_frameworks = select({
        "@rules_swift_package_manager//config_settings/spm/platform:ios": [
            "Foundation",
            "UIKit",
        ],
        "@rules_swift_package_manager//config_settings/spm/platform:macos": ["Foundation"],
        "@rules_swift_package_manager//config_settings/spm/platform:tvos": [
            "Foundation",
            "UIKit",
        ],
        "@rules_swift_package_manager//config_settings/spm/platform:watchos": [
            "Foundation",
            "UIKit",
        ],
        "//conditions:default": [],
    }),
    srcs = [
        "src/foo.m",
        "src/foo.h",
    ],
    textual_hdrs = ["src/foo.m"],
    visibility = ["//:__subpackages__"],
)

swift_interop_hint(
    name = "ObjcLibrary.rspm_swift_hint",
    module_map = "ObjcLibrary.rspm_modulemap",
    module_name = "ObjcLibrary",
)
""",
        ),
        struct(
            msg = "Objc target with a modulemap",
            name = "ObjcLibraryWithModulemap",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_interop_hint")

objc_library(
    name = "ObjcLibraryWithModulemap.rspm",
    deps = [":ObjcLibraryWithModulemap.rspm_objc"],
    visibility = ["//:__subpackages__"],
)

objc_library(
    name = "ObjcLibraryWithModulemap.rspm_objc",
    alwayslink = True,
    aspect_hints = ["ObjcLibraryWithModulemap.rspm_swift_hint"],
    copts = [
        "-fblocks",
        "-fobjc-arc",
        "-fPIC",
        "-DSWIFT_PACKAGE=1",
        "-fmodule-name=ObjcLibraryWithModulemap",
        "-Iexternal/bzlmodmangled~swiftpkg_mypackage/src",
    ],
    deps = ["@swiftpkg_mypackage//:ObjcLibraryDep.rspm"],
    enable_modules = True,
    hdrs = ["include/external.h"],
    includes = ["include"],
    sdk_frameworks = select({
        "@rules_swift_package_manager//config_settings/spm/platform:ios": [
            "Foundation",
            "UIKit",
        ],
        "@rules_swift_package_manager//config_settings/spm/platform:macos": ["Foundation"],
        "@rules_swift_package_manager//config_settings/spm/platform:tvos": [
            "Foundation",
            "UIKit",
        ],
        "@rules_swift_package_manager//config_settings/spm/platform:watchos": [
            "Foundation",
            "UIKit",
        ],
        "//conditions:default": [],
    }),
    srcs = [
        "src/foo.m",
        "src/foo.h",
    ],
    textual_hdrs = ["src/foo.m"],
    visibility = ["//:__subpackages__"],
)

swift_interop_hint(
    name = "ObjcLibraryWithModulemap.rspm_swift_hint",
    module_map = "include/module.modulemap",
    module_name = "ObjcLibraryWithModulemap",
)
""",
        ),
        struct(
            msg = "Swift target with conditional dep",
            name = "SwiftLibraryWithConditionalDep",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SwiftLibraryWithConditionalDep.rspm",
    always_include_developer_search_paths = True,
    alwayslink = True,
    copts = [
        "-DSWIFT_PACKAGE",
        "-Xcc",
        "-DSWIFT_PACKAGE",
    ],
    deps = ["@swiftpkg_mypackage//:ClangLibrary.rspm"] + select({
        "@rules_swift_package_manager//config_settings/spm/platform:ios": ["@swiftpkg_mypackage//:RegularSwiftTargetAsLibrary.rspm"],
        "@rules_swift_package_manager//config_settings/spm/platform:tvos": ["@swiftpkg_mypackage//:RegularSwiftTargetAsLibrary.rspm"],
        "//conditions:default": [],
    }),
    module_name = "SwiftLibraryWithConditionalDep",
    package_name = "MyPackage",
    srcs = ["Source/SwiftLibraryWithConditionalDep/SwiftLibraryWithConditionalDep.swift"],
    tags = ["manual"],
    visibility = ["//:__subpackages__"],
)
""",
        ),
        struct(
            msg = "Clang target with conditional dep",
            name = "ClangLibraryWithConditionalDep",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_interop_hint")
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "generate_modulemap")

cc_library(
    name = "ClangLibraryWithConditionalDep.rspm",
    deps = [
        ":ClangLibraryWithConditionalDep.rspm_modulemap",
        ":ClangLibraryWithConditionalDep.rspm_cxx",
    ],
    visibility = ["//:__subpackages__"],
)

cc_library(
    name = "ClangLibraryWithConditionalDep.rspm_cxx",
    alwayslink = True,
    aspect_hints = ["ClangLibraryWithConditionalDep.rspm_swift_hint"],
    copts = [
        "-fblocks",
        "-fobjc-arc",
        "-fPIC",
        "-DSWIFT_PACKAGE=1",
        "-fmodule-name=ClangLibraryWithConditionalDep",
        "-Iexternal/bzlmodmangled~swiftpkg_mypackage/src",
    ],
    deps = select({
        "@rules_swift_package_manager//config_settings/spm/platform:ios": ["@swiftpkg_mypackage//:ClangLibrary.rspm"],
        "@rules_swift_package_manager//config_settings/spm/platform:tvos": ["@swiftpkg_mypackage//:ClangLibrary.rspm"],
        "//conditions:default": [],
    }),
    hdrs = ["include/external.h"],
    includes = ["include"],
    srcs = [
        "src/foo.cc",
        "src/foo.h",
    ],
    textual_hdrs = ["src/foo.cc"],
    visibility = ["//:__subpackages__"],
)

generate_modulemap(
    name = "ClangLibraryWithConditionalDep.rspm_modulemap",
    deps = [],
    hdrs = ["include/external.h"],
    module_name = "ClangLibraryWithConditionalDep",
    visibility = ["//:__subpackages__"],
)

swift_interop_hint(
    name = "ClangLibraryWithConditionalDep.rspm_swift_hint",
    module_map = "ClangLibraryWithConditionalDep.rspm_modulemap",
    module_name = "ClangLibraryWithConditionalDep",
)
""",
        ),
        struct(
            msg = "Swift library target with @objc directives and Objc dep",
            name = "SwiftForObjcTarget",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SwiftForObjcTarget.rspm",
    always_include_developer_search_paths = True,
    alwayslink = True,
    copts = [
        "-DSWIFT_PACKAGE",
        "-Xcc",
        "-DSWIFT_PACKAGE",
    ],
    deps = ["@swiftpkg_mypackage//:ObjcLibraryDep.rspm"],
    features = ["swift.propagate_generated_module_map"],
    generates_header = True,
    module_name = "SwiftForObjcTarget",
    package_name = "MyPackage",
    srcs = ["Source/SwiftForObjcTarget/SwiftForObjcTarget.swift"],
    tags = ["manual"],
    visibility = ["//:__subpackages__"],
)
""",
        ),
        struct(
            msg = "Swift library target with file path resource",
            name = "SwiftLibraryWithFilePathResource",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "resource_bundle_accessor", "resource_bundle_infoplist")

apple_resource_bundle(
    name = "SwiftLibraryWithFilePathResource.rspm_resource_bundle",
    bundle_name = "MyPackage_SwiftLibraryWithFilePathResource",
    infoplists = [":SwiftLibraryWithFilePathResource.rspm_resource_bundle_infoplist"],
    resources = ["Source/SwiftLibraryWithFilePathResource/Resources/chicken.json"],
    visibility = ["//:__subpackages__"],
)

resource_bundle_accessor(
    name = "SwiftLibraryWithFilePathResource.rspm_resource_bundle_accessor",
    bundle_name = "MyPackage_SwiftLibraryWithFilePathResource",
)

resource_bundle_infoplist(
    name = "SwiftLibraryWithFilePathResource.rspm_resource_bundle_infoplist",
    region = "en",
)

swift_library(
    name = "SwiftLibraryWithFilePathResource.rspm",
    always_include_developer_search_paths = True,
    alwayslink = True,
    copts = [
        "-DSWIFT_PACKAGE",
        "-Xcc",
        "-DSWIFT_PACKAGE",
    ],
    data = [":SwiftLibraryWithFilePathResource.rspm_resource_bundle"],
    module_name = "SwiftLibraryWithFilePathResource",
    package_name = "MyPackage",
    srcs = [
        "Source/SwiftLibraryWithFilePathResource/SwiftLibraryWithFilePathResource.swift",
        ":SwiftLibraryWithFilePathResource.rspm_resource_bundle_accessor",
    ],
    tags = ["manual"],
    visibility = ["//:__subpackages__"],
)
""",
        ),
        struct(
            msg = "Objc target with resources",
            name = "ObjcLibraryWithResources",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_interop_hint")
load("@rules_swift_package_manager//swiftpkg:build_defs.bzl", "generate_modulemap", "objc_resource_bundle_accessor_hdr", "objc_resource_bundle_accessor_impl", "resource_bundle_infoplist")

apple_resource_bundle(
    name = "ObjcLibraryWithResources.rspm_resource_bundle",
    bundle_name = "MyPackage_ObjcLibraryWithResources",
    infoplists = [":ObjcLibraryWithResources.rspm_resource_bundle_infoplist"],
    resources = ["Source/ObjcLibraryWithResources/Resources/chicken.json"],
    visibility = ["//:__subpackages__"],
)

generate_modulemap(
    name = "ObjcLibraryWithResources.rspm_modulemap",
    deps = [],
    hdrs = ["include/external.h"],
    module_name = "ObjcLibraryWithResources",
    visibility = ["//:__subpackages__"],
)

objc_library(
    name = "ObjcLibraryWithResources.rspm",
    deps = [
        ":ObjcLibraryWithResources.rspm_modulemap",
        ":ObjcLibraryWithResources.rspm_objc",
    ],
    visibility = ["//:__subpackages__"],
)

objc_library(
    name = "ObjcLibraryWithResources.rspm_objc",
    alwayslink = True,
    aspect_hints = ["ObjcLibraryWithResources.rspm_swift_hint"],
    copts = [
        "-fblocks",
        "-fobjc-arc",
        "-fPIC",
        "-DSWIFT_PACKAGE=1",
        "-fmodule-name=ObjcLibraryWithResources",
        "-Iexternal/bzlmodmangled~swiftpkg_mypackage/src",
        "-include$(location :ObjcLibraryWithResources.rspm_objc_resource_bundle_accessor_hdr)",
    ],
    data = [":ObjcLibraryWithResources.rspm_resource_bundle"],
    enable_modules = True,
    hdrs = ["include/external.h"],
    includes = ["include"],
    sdk_frameworks = select({
        "@rules_swift_package_manager//config_settings/spm/platform:ios": [
            "Foundation",
            "UIKit",
        ],
        "@rules_swift_package_manager//config_settings/spm/platform:macos": ["Foundation"],
        "@rules_swift_package_manager//config_settings/spm/platform:tvos": [
            "Foundation",
            "UIKit",
        ],
        "@rules_swift_package_manager//config_settings/spm/platform:watchos": [
            "Foundation",
            "UIKit",
        ],
        "//conditions:default": [],
    }),
    srcs = [
        "src/foo.m",
        "src/foo.h",
        ":ObjcLibraryWithResources.rspm_objc_resource_bundle_accessor_hdr",
        ":ObjcLibraryWithResources.rspm_objc_resource_bundle_accessor_impl",
    ],
    textual_hdrs = ["src/foo.m"],
    visibility = ["//:__subpackages__"],
)

objc_resource_bundle_accessor_hdr(
    name = "ObjcLibraryWithResources.rspm_objc_resource_bundle_accessor_hdr",
    module_name = "ObjcLibraryWithResources",
)

objc_resource_bundle_accessor_impl(
    name = "ObjcLibraryWithResources.rspm_objc_resource_bundle_accessor_impl",
    bundle_name = "MyPackage_ObjcLibraryWithResources",
    extension = "m",
    module_name = "ObjcLibraryWithResources",
)

resource_bundle_infoplist(
    name = "ObjcLibraryWithResources.rspm_resource_bundle_infoplist",
    region = "en",
)

swift_interop_hint(
    name = "ObjcLibraryWithResources.rspm_swift_hint",
    module_map = "ObjcLibraryWithResources.rspm_modulemap",
    module_name = "ObjcLibraryWithResources",
)
""",
        ),
        struct(
            msg = "Swift library target with default visibility",
            name = "RegularSwiftTargetAsLibrary",
            pkg_info = _pkg_info(
                expose_build_targets = False,
            ),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "RegularSwiftTargetAsLibrary.rspm",
    always_include_developer_search_paths = True,
    alwayslink = True,
    copts = [
        "-DSWIFT_PACKAGE",
        "-Xcc",
        "-DSWIFT_PACKAGE",
    ],
    module_name = "RegularSwiftTargetAsLibrary",
    package_name = "MyPackage",
    srcs = ["Source/RegularSwiftTargetAsLibrary/RegularSwiftTargetAsLibrary.swift"],
    tags = ["manual"],
    visibility = ["//:__subpackages__"],
)
""",
        ),
        struct(
            msg = "Swift library target with public visibility",
            name = "RegularSwiftTargetAsLibrary",
            pkg_info = _pkg_info(
                expose_build_targets = True,
            ),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "RegularSwiftTargetAsLibrary.rspm",
    always_include_developer_search_paths = True,
    alwayslink = True,
    copts = [
        "-DSWIFT_PACKAGE",
        "-Xcc",
        "-DSWIFT_PACKAGE",
    ],
    module_name = "RegularSwiftTargetAsLibrary",
    package_name = "MyPackage",
    srcs = ["Source/RegularSwiftTargetAsLibrary/RegularSwiftTargetAsLibrary.swift"],
    tags = ["manual"],
    visibility = ["//visibility:public"],
)
""",
        ),
    ]
    for t in tests:
        target = pkginfo_targets.get(t.pkg_info.targets, t.name)
        repository_ctx = testutils.new_stub_repository_ctx(
            repo_name = _repo_name[1:],
            file_contents = {
                paths.normalize(paths.join(t.pkg_info.path, target.path, fname)): cnts
                for fname, cnts in getattr(t, "file_contents", {}).items()
            },
            find_results = {
                paths.normalize(paths.join(t.pkg_info.path, dirname)): [
                    paths.normalize(paths.join(t.pkg_info.path, dirname, fp))
                    for fp in file_paths
                ]
                for dirname, file_paths in getattr(t, "find_results", {}).items()
            },
            is_directory_results = {
                paths.normalize(paths.join(target.path, path)): result
                for path, result in getattr(t, "is_directory", {}).items()
            },
        )
        actual = scg.to_starlark(
            swiftpkg_build_files.new_for_target(repository_ctx, _pkg_ctx(t.pkg_info), target),
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
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_binary")

swift_binary(
    name = "oldstyleexec",
    deps = ["@swiftpkg_mypackage//:RegularTargetForExec.rspm"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Swift library product",
            name = "RegularSwiftTargetAsLibrary",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library_group")

swift_library_group(
    name = "RegularSwiftTargetAsLibrary",
    deps = ["@swiftpkg_mypackage//:RegularSwiftTargetAsLibrary.rspm"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "ObjC library with modulemap product",
            name = "ObjcLibraryWithModulemap",
            pkg_info = _pkg_info(),
            exp = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library_group")

swift_library_group(
    name = "ObjcLibraryWithModulemap",
    deps = ["@swiftpkg_mypackage//:ObjcLibraryWithModulemap.rspm"],
    visibility = ["//visibility:public"],
)
""",
        ),
        struct(
            msg = "Swift exectable product",
            name = "swiftexec",
            pkg_info = _pkg_info(),
            exp = """\

alias(
    name = "swiftexec",
    actual = "@swiftpkg_mypackage//:SwiftExecutableTarget.rspm",
    visibility = ["//visibility:public"],
)
""",
        ),
    ]
    for t in tests:
        product = lists.find(t.pkg_info.products, lambda p: p.name == t.name)
        actual = scg.to_starlark(
            swiftpkg_build_files.new_for_product(
                pkg_ctx = _pkg_ctx(t.pkg_info),
                product = product,
            ),
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

product_generation_test = unittest.make(_product_generation_test)

def _license_generation_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "No license",
            license = None,
            pkg_info = _pkg_info(),
            exp = """\
load("@rules_license//rules:package_info.bzl", "package_info")

package(
    default_package_metadata = [":package_info.rspm"],
)

package_info(
    name = "package_info.rspm",
    package_name = "MyPackage",
    package_url = "https://github.com/my/package",
    package_version = "0.4.2",
)
""",
        ),
        struct(
            msg = "Markdown license",
            license = "LICENSE.md",
            pkg_info = _pkg_info(),
            exp = """\
load("@rules_license//rules:package_info.bzl", "package_info")
load("@rules_license//rules:license.bzl", "license")

package(
    default_package_metadata = [
        ":license.rspm",
        ":package_info.rspm",
    ],
)

package_info(
    name = "package_info.rspm",
    package_name = "MyPackage",
    package_url = "https://github.com/my/package",
    package_version = "0.4.2",
)

license(
    name = "license.rspm",
    license_text = "LICENSE.md",
)
""",
        ),
        struct(
            msg = "License",
            license = "LICENSE",
            pkg_info = _pkg_info(),
            exp = """\
load("@rules_license//rules:package_info.bzl", "package_info")
load("@rules_license//rules:license.bzl", "license")

package(
    default_package_metadata = [
        ":license.rspm",
        ":package_info.rspm",
    ],
)

package_info(
    name = "package_info.rspm",
    package_name = "MyPackage",
    package_url = "https://github.com/my/package",
    package_version = "0.4.2",
)

license(
    name = "license.rspm",
    license_text = "LICENSE",
)
""",
        ),
    ]
    for t in tests:
        actual = scg.to_starlark(
            swiftpkg_build_files.new_for_license(
                pkg_info = t.pkg_info,
                license = t.license,
            ),
        )
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

license_generation_test = unittest.make(_license_generation_test)

def swiftpkg_build_files_test_suite():
    return unittest.suite(
        "swiftpkg_build_files_tests",
        target_generation_test,
        product_generation_test,
        license_generation_test,
    )
