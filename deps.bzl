"""Specifies the workspace dependencies for the `rules_swift_package_manager` repository."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# buildifier: disable=unnamed-macro
def swift_bazel_dependencies():
    """Declare the Bazel workspace dependencies for the `rules_swift_package_manager` repository."""

    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "b8a1527901774180afc798aeb28c4634bdccf19c4d98e7bdd1ce79d1fe9aaad7",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.4.1/bazel-skylib-1.4.1.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.4.1/bazel-skylib-1.4.1.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "io_bazel_rules_go",
        sha256 = "6dc2da7ab4cf5d7bfc7c949776b1b7c733f05e56edc4bcd9022bb249d2e2a996",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.39.1/rules_go-v0.39.1.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.39.1/rules_go-v0.39.1.zip",
        ],
    )

    # GH143: Waiting for bazel-gazelle release with dep fix:
    # https://github.com/bazelbuild/bazel-gazelle/pull/1413
    # maybe(
    #     http_archive,
    #     name = "bazel_gazelle",
    #     sha256 = "ecba0f04f96b4960a5b250c8e8eeec42281035970aa8852dda73098274d14a1d",
    #     urls = [
    #         "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.29.0/bazel-gazelle-v0.29.0.tar.gz",
    #         "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.29.0/bazel-gazelle-v0.29.0.tar.gz",
    #     ],
    # )

    maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "3b47b1ce22acc00f313eef61c0e29936cd0c291c01f0250f0b736f0dbadccb42",
        strip_prefix = "bazel-gazelle-fb019437f6fbc582263a6e4c5d7ede6a122ed492",
        urls = [
            "https://github.com/bazelbuild/bazel-gazelle/archive/fb019437f6fbc582263a6e4c5d7ede6a122ed492.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "cgrindel_bazel_starlib",
        sha256 = "ee0033d029b5eaddc21836b2944cf37c95eb5f214eb39834136a316dbc252a73",
        urls = [
            "https://github.com/cgrindel/bazel-starlib/releases/download/v0.16.0/bazel-starlib.v0.16.0.tar.gz",
        ],
    )
