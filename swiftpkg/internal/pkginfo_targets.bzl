"""Module for generating data from targets created by `package_infos`."""

load("@bazel_skylib//lib:paths.bzl", "paths")

def _srcs(target):
    return [
        paths.join(target.path, src)
        for src in target.sources
    ]

pkginfo_targets = struct(
    srcs = _srcs,
)
