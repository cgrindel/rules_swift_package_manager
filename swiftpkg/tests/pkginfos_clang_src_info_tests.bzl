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

def _header_search_path_headers_are_sorted_test(ctx):
    # Headers under a header search path outside of the target are added to
    # `srcs`. Their order must not depend on the filesystem order.
    env = unittest.begin(ctx)

    shared_hdrs = [
        "/pkg/Sources/Shared/Zeta.h",
        "/pkg/Sources/Shared/Alpha.h",
        "/pkg/Sources/Shared/Nested/Beta.h",
        "/pkg/Sources/Shared/Mid.h",
    ]
    for find_order in [shared_hdrs, reversed(shared_hdrs)]:
        repository_ctx = testutils.new_stub_repository_ctx(
            "lib",
            find_results = {
                "/pkg/Sources/Lib": [
                    "/pkg/Sources/Lib/include/Lib.h",
                    "/pkg/Sources/Lib/Lib.m",
                ],
                "/pkg/Sources/Shared": list(find_order),
            },
            path_exists_results = {
                "/pkg/Sources/Shared": True,
            },
        )

        actual = pkginfos_testing.new_clang_src_info_from_sources(
            repository_ctx = repository_ctx,
            pkg_path = "/pkg",
            c99name = "Lib",
            target_path = "Sources/Lib",
            source_paths = None,
            public_hdrs_path = "include",
            exclude_paths = [],
            other_hdr_srch_paths = [struct(values = ["../Shared"])],
        )

        asserts.equals(
            env,
            [
                "Sources/Shared/Alpha.h",
                "Sources/Shared/Mid.h",
                "Sources/Shared/Nested/Beta.h",
                "Sources/Shared/Zeta.h",
            ],
            actual.organized_srcs.other_srcs,
        )
        asserts.equals(
            env,
            ["Sources/Lib/Lib.m"],
            actual.organized_srcs.objc_srcs,
        )
        asserts.equals(env, ["Sources/Lib/include/Lib.h"], actual.hdrs)

    return unittest.end(env)

header_search_path_headers_are_sorted_test = unittest.make(
    _header_search_path_headers_are_sorted_test,
)

def _new_excluded_files_src_info(
        exclude_paths,
        lib_files = [],
        find_results = {},
        is_directory_results = {},
        path_exists_results = {}):
    # Build the clang source info for a `Lib` target at `/pkg/Sources/Lib`
    # that has a public header and a source file plus `lib_files`. Note that
    # every non-header source, including the compiled `Lib.c`, is also listed
    # in `textual_hdrs` (GH252).
    all_find_results = {
        "/pkg/Sources/Lib": [
            "/pkg/Sources/Lib/Lib.c",
            "/pkg/Sources/Lib/include/Lib.h",
        ] + lib_files,
    }
    all_find_results.update(find_results)
    repository_ctx = testutils.new_stub_repository_ctx(
        "lib",
        find_results = all_find_results,
        is_directory_results = is_directory_results,
        path_exists_results = path_exists_results,
    )
    return pkginfos_testing.new_clang_src_info_from_sources(
        repository_ctx = repository_ctx,
        pkg_path = "/pkg",
        c99name = "Lib",
        target_path = "Sources/Lib",
        source_paths = None,
        public_hdrs_path = "include",
        exclude_paths = exclude_paths,
    )

def _excluded_header_file_is_kept_test(ctx):
    env = unittest.begin(ctx)

    actual = _new_excluded_files_src_info(
        exclude_paths = ["include/Excluded.h"],
        lib_files = ["/pkg/Sources/Lib/include/Excluded.h"],
        path_exists_results = {
            "/pkg/Sources/Lib/include/Excluded.h": True,
        },
    )

    asserts.equals(
        env,
        ["Sources/Lib/include/Excluded.h", "Sources/Lib/include/Lib.h"],
        actual.hdrs,
    )

    return unittest.end(env)

excluded_header_file_is_kept_test = unittest.make(
    _excluded_header_file_is_kept_test,
)

def _excluded_inc_file_is_kept_test(ctx):
    env = unittest.begin(ctx)

    actual = _new_excluded_files_src_info(
        exclude_paths = ["table.inc"],
        lib_files = ["/pkg/Sources/Lib/table.inc"],
        path_exists_results = {
            "/pkg/Sources/Lib/table.inc": True,
        },
    )

    asserts.equals(
        env,
        ["Sources/Lib/table.inc"],
        actual.organized_srcs.other_srcs,
    )
    asserts.equals(env, ["Sources/Lib/Lib.c"], actual.organized_srcs.c_srcs)

    return unittest.end(env)

excluded_inc_file_is_kept_test = unittest.make(
    _excluded_inc_file_is_kept_test,
)

def _excluded_c_file_is_textual_hdr_test(ctx):
    env = unittest.begin(ctx)

    actual = _new_excluded_files_src_info(
        exclude_paths = ["Excluded.c"],
        lib_files = ["/pkg/Sources/Lib/Excluded.c"],
        path_exists_results = {
            "/pkg/Sources/Lib/Excluded.c": True,
        },
    )

    asserts.equals(
        env,
        ["Sources/Lib/Excluded.c", "Sources/Lib/Lib.c"],
        actual.textual_hdrs,
    )
    asserts.equals(env, ["Sources/Lib/Lib.c"], actual.organized_srcs.c_srcs)
    asserts.false(env, "Sources/Lib/Excluded.c" in actual.explicit_srcs)

    return unittest.end(env)

excluded_c_file_is_textual_hdr_test = unittest.make(
    _excluded_c_file_is_textual_hdr_test,
)

def _c_file_in_excluded_directory_is_textual_hdr_test(ctx):
    env = unittest.begin(ctx)

    impl_files = [
        "/pkg/Sources/Lib/impl/impl.c",
        "/pkg/Sources/Lib/impl/impl.h",
    ]
    actual = _new_excluded_files_src_info(
        exclude_paths = ["impl"],
        lib_files = impl_files,
        find_results = {
            "/pkg/Sources/Lib/impl": impl_files,
        },
        is_directory_results = {
            "/pkg/Sources/Lib/impl": True,
        },
    )

    asserts.equals(
        env,
        ["Sources/Lib/Lib.c", "Sources/Lib/impl/impl.c"],
        actual.textual_hdrs,
    )
    asserts.equals(env, ["Sources/Lib/Lib.c"], actual.organized_srcs.c_srcs)
    asserts.equals(
        env,
        ["Sources/Lib/impl/impl.h"],
        actual.organized_srcs.other_srcs,
    )

    return unittest.end(env)

c_file_in_excluded_directory_is_textual_hdr_test = unittest.make(
    _c_file_in_excluded_directory_is_textual_hdr_test,
)

def _file_excluded_twice_is_listed_once_test(ctx):
    env = unittest.begin(ctx)

    actual = _new_excluded_files_src_info(
        exclude_paths = ["Excluded.c", "./Excluded.c"],
        lib_files = ["/pkg/Sources/Lib/Excluded.c"],
        path_exists_results = {
            "/pkg/Sources/Lib/Excluded.c": True,
        },
    )

    asserts.equals(
        env,
        ["Sources/Lib/Excluded.c", "Sources/Lib/Lib.c"],
        actual.textual_hdrs,
    )

    return unittest.end(env)

file_excluded_twice_is_listed_once_test = unittest.make(
    _file_excluded_twice_is_listed_once_test,
)

def _textual_hdrs_are_sorted_test(ctx):
    env = unittest.begin(ctx)

    actual = _new_excluded_files_src_info(
        exclude_paths = ["zeta.c", "alpha.c"],
        lib_files = [
            "/pkg/Sources/Lib/alpha.c",
            "/pkg/Sources/Lib/mid.def",
            "/pkg/Sources/Lib/zeta.c",
        ],
        path_exists_results = {
            "/pkg/Sources/Lib/alpha.c": True,
            "/pkg/Sources/Lib/zeta.c": True,
        },
    )

    asserts.equals(
        env,
        [
            "Sources/Lib/Lib.c",
            "Sources/Lib/alpha.c",
            "Sources/Lib/mid.def",
            "Sources/Lib/zeta.c",
        ],
        actual.textual_hdrs,
    )

    return unittest.end(env)

textual_hdrs_are_sorted_test = unittest.make(_textual_hdrs_are_sorted_test)

def pkginfos_clang_src_info_test_suite():
    unittest.suite(
        "pkginfos_clang_src_info_tests",
        explicit_source_paths_do_not_compile_public_include_sources_test,
        explicit_source_paths_keep_separate_public_include_test,
        explicit_source_file_discovers_sibling_public_headers_test,
        header_search_path_headers_are_sorted_test,
        excluded_header_file_is_kept_test,
        excluded_inc_file_is_kept_test,
        excluded_c_file_is_textual_hdr_test,
        c_file_in_excluded_directory_is_textual_hdr_test,
        file_excluded_twice_is_listed_once_test,
        textual_hdrs_are_sorted_test,
    )
