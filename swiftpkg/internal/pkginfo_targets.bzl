"""Module for generating data from targets created by `package_infos`."""

load("@bazel_skylib//lib:paths.bzl", "paths")

def _srcs_from_target(target):
    return [
        paths.join(t.path, src)
        for src in target.sources
    ]

pkginfo_targets = struct(
    srcs = _srcs_from_target,
)
