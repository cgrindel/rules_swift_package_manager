"""Module for creating a module index context for a package info."""

load(":pkginfos.bzl", "pkginfos")
load(":repository_utils.bzl", "repository_utils")

def _read(
        repository_ctx,
        repo_dir,
        env,
        resolved_pkg_map = None,
        registries_directory = None,
        replace_scm_with_registry = False):
    pkg_info = pkginfos.get(
        repository_ctx = repository_ctx,
        directory = repo_dir,
        env = env,
        resolved_pkg_map = resolved_pkg_map,
        registries_directory = registries_directory,
        replace_scm_with_registry = replace_scm_with_registry,
    )
    return _new(
        pkg_info = pkg_info,
        repo_name = repository_utils.package_name(repository_ctx),
    )

def _new(pkg_info, repo_name):
    return struct(
        pkg_info = pkg_info,
        repo_name = repo_name,
    )

pkg_ctxs = struct(
    new = _new,
    read = _read,
)
