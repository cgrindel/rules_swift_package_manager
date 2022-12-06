"""Module for generating data from targets created by `package_infos`."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(":pkginfo_target_deps.bzl", "pkginfo_target_deps")

# TODO(chuck): Add documentation.

def _srcs(target):
    return [
        paths.join(target.path, src)
        for src in target.sources
    ]

def make_pkginfo_targets(pkginfo_target_deps = pkginfo_target_deps):
    def _deps(pkg_info, target):
        return [
            pkginfo_target_deps.bazel_label(pkg_info, td)
            for td in target.dependencies
        ]

    return struct(
        srcs = _srcs,
        deps = _deps,
    )

pkginfo_targets = make_pkginfo_targets(pkginfo_target_deps = pkginfo_target_deps)
