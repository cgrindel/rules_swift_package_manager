"""Module for generating data from targets created by `package_infos`."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(":pkginfo_target_deps.bzl", "pkginfo_target_deps")

# TODO(chuck): Add documentation.

def _srcs(target):
    return [
        paths.join(target.path, src)
        for src in target.sources
    ]

def _deps(target):
    return [
        pkginfo_target_deps.bzl_dep(td)
        for td in target.dependencies
    ]

pkginfo_targets = struct(
    srcs = _srcs,
)
