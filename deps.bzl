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
        sha256 = "c8035e8ae248b56040a65ad3f0b7434712e2037e5dfdcebfe97576e620422709",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.44.0/rules_go-v0.44.0.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.44.0/rules_go-v0.44.0.zip",
        ],
    )

    maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "32938bda16e6700063035479063d9d24c60eda8d79fd4739563f50d331cb3209",
        urls = [
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.35.0/bazel-gazelle-v0.35.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "cgrindel_bazel_starlib",
        sha256 = "b9c88ac51ccaa0635621111308b85fdbb2606adb864596f9842aa5f7480cfe3a",
        urls = [
            "https://github.com/cgrindel/bazel-starlib/releases/download/v0.19.0/bazel-starlib.v0.19.0.tar.gz",
        ],
    )
