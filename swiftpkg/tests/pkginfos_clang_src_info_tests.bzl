"""Tests for `pkginfos` clang source info collection."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos_testing")
load(":testutils.bzl", "testutils")

def _explicit_source_paths_do_not_compile_public_include_sources_test(ctx):
    env = unittest.begin(ctx)

    repository_ctx = testutils.new_stub_repository_ctx(
        "yoga",
        file_contents = {
            "/pkg/yoga/module.modulemap": """
module core {
  header "YGConfig.h"
  export *
}
""",
        },
        find_results = {
            "/pkg": [
                "/pkg/benchmark/Benchmark.h",
                "/pkg/javascript/src/wasm_bridge.c",
                "/pkg/yoga/YGConfig.cpp",
                "/pkg/yoga/YGConfig.h",
                "/pkg/yoga/module.modulemap",
            ],
            "/pkg/yoga": [
                "/pkg/yoga/YGConfig.cpp",
                "/pkg/yoga/YGConfig.h",
                "/pkg/yoga/module.modulemap",
            ],
        },
        is_directory_results = {
            "/pkg/yoga": True,
        },
    )

    actual = pkginfos_testing.new_clang_src_info_from_sources(
        repository_ctx = repository_ctx,
        pkg_path = "/pkg",
        c99name = "core",
        target_path = ".",
        source_paths = ["yoga"],
        public_hdrs_path = ".",
        exclude_paths = [],
    )

    asserts.equals(
        env,
        ["yoga/YGConfig.cpp"],
        sorted(actual.explicit_srcs),
    )
    asserts.equals(env, [], actual.organized_srcs.c_srcs)
    asserts.equals(
        env,
        ["yoga/YGConfig.cpp"],
        sorted(actual.organized_srcs.cxx_srcs),
    )
    asserts.false(
        env,
        "javascript/src/wasm_bridge.c" in actual.explicit_srcs,
    )
    asserts.equals(
        env,
        ["yoga/YGConfig.h"],
        sorted(actual.hdrs),
    )
    asserts.false(
        env,
        "benchmark/Benchmark.h" in actual.hdrs,
    )
    asserts.equals(env, "yoga/module.modulemap", actual.modulemap_path)
    asserts.equals(env, "core", actual.module_name)

    return unittest.end(env)

explicit_source_paths_do_not_compile_public_include_sources_test = unittest.make(
    _explicit_source_paths_do_not_compile_public_include_sources_test,
)

def _explicit_source_paths_keep_separate_public_include_test(ctx):
    env = unittest.begin(ctx)

    repository_ctx = testutils.new_stub_repository_ctx(
        "cpackage",
        file_contents = {
            "/pkg/include/module.modulemap": """
module core {
  header "Core.h"
  export *
}
""",
        },
        find_results = {
            "/pkg/include": [
                "/pkg/include/Core.h",
                "/pkg/include/module.modulemap",
            ],
            "/pkg/src": [
                "/pkg/src/Core.c",
            ],
        },
    )

    actual = pkginfos_testing.new_clang_src_info_from_sources(
        repository_ctx = repository_ctx,
        pkg_path = "/pkg",
        c99name = "core",
        target_path = ".",
        source_paths = ["src"],
        public_hdrs_path = "include",
        exclude_paths = [],
    )

    asserts.equals(
        env,
        ["src/Core.c"],
        sorted(actual.explicit_srcs),
    )
    asserts.equals(
        env,
        ["include/Core.h"],
        sorted(actual.hdrs),
    )
    asserts.equals(env, "include/module.modulemap", actual.modulemap_path)
    asserts.equals(env, "core", actual.module_name)

    return unittest.end(env)

explicit_source_paths_keep_separate_public_include_test = unittest.make(
    _explicit_source_paths_keep_separate_public_include_test,
)

def _explicit_source_file_discovers_sibling_public_headers_test(ctx):
    # Regression test for a target that names an individual source file (rather
    # than a directory) while its public headers path is the directory that
    # contains both that file and sibling headers, e.g.:
    #   path: "Sources/CLib", sources: ["util.c"], publicHeadersPath: "."
    # The sibling `util.h` must still be discovered as a public header.
    env = unittest.begin(ctx)

    repository_ctx = testutils.new_stub_repository_ctx(
        "clib",
        find_results = {
            # Scanning the file's containing directory finds the sibling header.
            "/pkg/Sources/CLib": [
                "/pkg/Sources/CLib/util.c",
                "/pkg/Sources/CLib/util.h",
            ],
            # The explicit source path is a file; listing it returns itself.
            "/pkg/Sources/CLib/util.c": [
                "/pkg/Sources/CLib/util.c",
            ],
        },
        # util.c is a file, not a directory.
        is_directory_results = {},
    )

    actual = pkginfos_testing.new_clang_src_info_from_sources(
        repository_ctx = repository_ctx,
        pkg_path = "/pkg",
        c99name = "CLib",
        target_path = "Sources/CLib",
        source_paths = ["util.c"],
        public_hdrs_path = ".",
        exclude_paths = [],
    )

    asserts.equals(
        env,
        ["Sources/CLib/util.c"],
        sorted(actual.explicit_srcs),
    )
    asserts.equals(
        env,
        ["Sources/CLib/util.h"],
        sorted(actual.hdrs),
    )

    return unittest.end(env)

explicit_source_file_discovers_sibling_public_headers_test = unittest.make(
    _explicit_source_file_discovers_sibling_public_headers_test,
)

def pkginfos_clang_src_info_test_suite():
    unittest.suite(
        "pkginfos_clang_src_info_tests",
        explicit_source_paths_do_not_compile_public_include_sources_test,
        explicit_source_paths_keep_separate_public_include_test,
        explicit_source_file_discovers_sibling_public_headers_test,
    )
