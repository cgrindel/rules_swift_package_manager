"""Module for generating data from targets created by `package_infos`."""

# load(":pkginfo_target_deps.bzl", "pkginfo_target_deps")

# TODO(chuck): Add documentation.

# def _srcs(target):
#     return [
#         paths.join(target.path, src)
#         for src in target.sources
#     ]

def _get(targets, name, fail_if_not_found = True):
    for target in targets:
        if target.name == name:
            return target
    if fail_if_not_found:
        fail("Failed to find target. name:", name)
    return None

# def make_pkginfo_targets(pkginfo_target_deps = pkginfo_target_deps):
#     # def _deps(pkg_info, target):
#     #     return [
#     #         pkginfo_target_deps.bazel_label(pkg_info, td)
#     #         for td in target.dependencies
#     #     ]

#     return struct(
#         # srcs = _srcs,
#         # deps = _deps,
#         get = _get,
#     )

# pkginfo_targets = make_pkginfo_targets(pkginfo_target_deps = pkginfo_target_deps)

pkginfo_targets = struct(
    get = _get,
)
