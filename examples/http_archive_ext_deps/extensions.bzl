load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _non_module_deps_impl(_):
    # Example of defining Swift targets in a separate build file
    http_archive(
        name = "com_github_apple_swift_collections",
        build_file = "@//third_party:swift_collections.BUILD.bazel",
        sha256 = "59ca5676b2662021f3046becb7824747c002637677b953fc059ee555f1e0b438",
        strip_prefix = "swift-collections-1.1.0",
        url = "https://github.com/apple/swift-collections/archive/refs/tags/1.1.0.tar.gz",
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
        sha256 = "d5bad3a1da66d9f4ceb0a347a197b8fdd243a91ff6b2d72b78efb052b9d6dd33",
        strip_prefix = "swift-argument-parser-1.4.0",
        url = "https://github.com/apple/swift-argument-parser/archive/1.4.0.tar.gz",
    )

non_module_deps = module_extension(implementation = _non_module_deps_impl)
