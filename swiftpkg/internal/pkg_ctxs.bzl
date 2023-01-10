"""Module for creating a module index context for a package info."""

load(":deps_indexes.bzl", "deps_indexes")
load(":pkginfo_ext_deps.bzl", "pkginfo_ext_deps")

def _new(pkg_info, repo_name, deps_index_json):
    return struct(
        pkg_info = pkg_info,
        repo_name = repo_name,
        deps_index_ctx = deps_indexes.new_ctx(
            deps_index = deps_indexes.new_from_json(deps_index_json),
            preferred_repo_name = repo_name,
            restrict_to_repo_names = [repo_name] + [
                pkginfo_ext_deps.bazel_repo_name(dep)
                for dep in pkg_info.dependencies
            ],
        ),
    )

pkg_ctxs = struct(
    new = _new,
)
