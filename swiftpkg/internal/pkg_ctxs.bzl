"""Module for creating a module index context for a package info."""

load(":deps_indexes.bzl", "deps_indexes")
load(":pkginfo_ext_deps.bzl", "pkginfo_ext_deps")
load(":pkginfos.bzl", "pkginfos")
load(":repository_utils.bzl", "repository_utils")

def _read(repository_ctx, repo_dir, env):
    deps_index_json = repository_ctx.read(
        repository_ctx.attr.dependencies_index,
    )
    deps_index = deps_indexes.new_from_json(deps_index_json)
    pkg_info = pkginfos.get(
        repository_ctx = repository_ctx,
        directory = repo_dir,
        deps_index = deps_index,
        env = env,
    )
    return _new(
        pkg_info = pkg_info,
        repo_name = repository_utils.package_name(repository_ctx),
        deps_index = deps_index,
    )

def _new(pkg_info, repo_name, deps_index):
    return struct(
        pkg_info = pkg_info,
        repo_name = repo_name,
        deps_index_ctx = deps_indexes.new_ctx(
            deps_index = deps_index,
            preferred_repo_name = repo_name,
            restrict_to_repo_names = [repo_name] + [
                pkginfo_ext_deps.bazel_repo_name(dep)
                for dep in pkg_info.dependencies
            ],
        ),
    )

pkg_ctxs = struct(
    new = _new,
    read = _read,
)
