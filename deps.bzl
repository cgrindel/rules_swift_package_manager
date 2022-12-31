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
        sha256 = "9cade3c63c8a1e13898ca04c85492005df12ca9521743c908fa1eb627b6778b6",
        strip_prefix = "bazel-gazelle-18531e360ab3d1a2e1beac841b48c925ad487da3",
        urls = [
            "https://github.com/bazelbuild/bazel-gazelle/archive/18531e360ab3d1a2e1beac841b48c925ad487da3.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "cgrindel_bazel_starlib",
        sha256 = "2b5031fd24ccc0bddcccd18c61d50c41970ad9757f15690ce6874935f298b05b",
        strip_prefix = "bazel-starlib-0.10.3",
        urls = [
            "http://github.com/cgrindel/bazel-starlib/archive/v0.10.3.tar.gz",
        ],
    )
