load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _non_module_deps_impl(_):
    # Example of defining Swift targets in a separate build file
    http_archive(
        name = "com_github_apple_swift_collections",
        build_file = "@//third_party:swift_collections.BUILD.bazel",
        sha256 = "b18c522aff4241160f60bcd0695702657c7862512c994c260a7d63f15a8450d8",
        strip_prefix = "swift-collections-1.0.2",
        url = "https://github.com/apple/swift-collections/archive/refs/tags/1.0.2.tar.gz",
    )

    # Example of defining Swift targets inline.
    http_archive(
        name = "com_github_apple_swift_argument_parser",
        build_file_content = """\
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
swift_library(
    name = "ArgumentParser",
    srcs = glob(["Sources/ArgumentParser/**/*.swift"]),
    visibility = ["//visibility:public"],
    deps = [":ArgumentParserToolInfo"],
)
swift_library(
    name = "ArgumentParserToolInfo",
    srcs = glob(["Sources/ArgumentParserToolInfo/**/*.swift"]),
    visibility = ["//visibility:public"],
)
""",
        sha256 = "f2c3a7f20e6dede610e7bd7e6cc9e352df54070769bc5b7f5d4bb2868e3c10ae",
        strip_prefix = "swift-argument-parser-1.2.0",
        url = "https://github.com/apple/swift-argument-parser/archive/1.2.0.tar.gz",
    )

non_module_deps = module_extension(implementation = _non_module_deps_impl)
