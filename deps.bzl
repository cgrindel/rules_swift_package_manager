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
        sha256 = "4dd05f44200db3b78f72f56ebd8b102d5bcdc17c0299955d4eb20c38c6f07cd7",
        strip_prefix = "bazel-skylib-1.4.0",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/archive/1.4.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "io_bazel_rules_go",
        sha256 = "dd926a88a564a9246713a9c00b35315f54cbd46b31a26d5d8fb264c07045f05d",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.38.1/rules_go-v0.38.1.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.38.1/rules_go-v0.38.1.zip",
        ],
    )

    maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "ecba0f04f96b4960a5b250c8e8eeec42281035970aa8852dda73098274d14a1d",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.29.0/bazel-gazelle-v0.29.0.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.29.0/bazel-gazelle-v0.29.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "cgrindel_bazel_starlib",
        sha256 = "3f04ca2e3bef99563c6d96728b0a09f8484bc3c61ca804d29f67e86e6043c038",
        strip_prefix = "bazel-starlib-0.11.0",
        urls = [
            "http://github.com/cgrindel/bazel-starlib/archive/v0.11.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "build_bazel_rules_swift",
        sha256 = "84e2cc1c9e3593ae2c0aa4c773bceeb63c2d04c02a74a6e30c1961684d235593",
        url = "https://github.com/bazelbuild/rules_swift/releases/download/1.5.1/rules_swift.1.5.1.tar.gz",
    )
