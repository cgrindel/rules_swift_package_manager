"""Specifies the workspace dependencies for the `rules_swift_package_manager` repository."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# buildifier: disable=unnamed-macro
def swift_bazel_dependencies():
    """Declare the Bazel workspace dependencies for the `rules_swift_package_manager` repository."""

    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "cd55a062e763b9349921f0f5db8c3933288dc8ba4f76dd9416aac68acee3cb94",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.5.0/bazel-skylib-1.5.0.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.5.0/bazel-skylib-1.5.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "io_bazel_rules_go",
        sha256 = "af47f30e9cbd70ae34e49866e201b3f77069abb111183f2c0297e7e74ba6bbc0",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.47.0/rules_go-v0.47.0.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.47.0/rules_go-v0.47.0.zip",
        ],
    )

    maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "75df288c4b31c81eb50f51e2e14f4763cb7548daae126817247064637fd9ea62",
        urls = [
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.36.0/bazel-gazelle-v0.36.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "cgrindel_bazel_starlib",
        sha256 = "00b084e895146d2dc8c76437dd5f91a7203c7b46bb4edd1896d018b8795bc927",
        urls = [
            "https://github.com/cgrindel/bazel-starlib/releases/download/v0.20.2/bazel-starlib.v0.20.2.tar.gz",
        ],
    )
