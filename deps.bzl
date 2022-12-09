"""Specifies the workspace dependencies for the `swift_bazel` repository."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# buildifier: disable=unnamed-macro
def swift_bazel_dependencies():
    """Declare the Bazel workspace dependencies for the `swift_bazel` repository."""

    # 2022-11-08: Retrieving the source archive so that I can use the gazelle
    # plugin. Work is happening to include it in the distribution.
    # https://github.com/bazelbuild/bazel-skylib/pull/400
    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 =
            "3b620033ca48fcd6f5ef2ac85e0f6ec5639605fa2f627968490e52fc91a9932f",
        strip_prefix = "bazel-skylib-1.3.0",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/archive/1.3.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "io_bazel_rules_go",
        sha256 = "56d8c5a5c91e1af73eca71a6fab2ced959b67c86d12ba37feedb0a2dfea441a6",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.37.0/rules_go-v0.37.0.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.37.0/rules_go-v0.37.0.zip",
        ],
    )

    # Post v0.28.0: Contains fix for passing test args to gazelle_generation_test.
    maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "9752b46d35760b01cc3b1ebaea6177189743dc282ea9276c3ad64dcd67b299f4",
        strip_prefix = "bazel-gazelle-5e06b9479bc41f57d5730962feabf25dda938461",
        urls = [
            "https://github.com/bazelbuild/bazel-gazelle/archive/5e06b9479bc41f57d5730962feabf25dda938461.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "cgrindel_bazel_starlib",
        sha256 = "5e87de5b647345bf757737208cb6e524da6ce74794948e3fb45ef937fa2eb9e7",
        strip_prefix = "bazel-starlib-0.10.2",
        urls = [
            "http://github.com/cgrindel/bazel-starlib/archive/v0.10.2.tar.gz",
        ],
    )
