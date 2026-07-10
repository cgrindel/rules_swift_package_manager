"""Module for creating a module index context for a package info."""

load(":manual_target_deps.bzl", "manual_target_deps")
load(":pkginfos.bzl", "pkginfos")
load(":repository_utils.bzl", "repository_utils")

def _read(
        repository_ctx,
        repo_dir,
        env,
        cached_json_directory,
        resolved_pkg_map = None,
        registries_directory = None,
        replace_scm_with_registry = False,
        target_deps = {},
        module_aliases = {},
        dep_module_aliases = ""):
    pkg_info = pkginfos.get(
        repository_ctx = repository_ctx,
        directory = repo_dir,
        env = env,
        cached_json_directory = cached_json_directory,
        resolved_pkg_map = resolved_pkg_map,
        registries_directory = registries_directory,
        replace_scm_with_registry = replace_scm_with_registry,
    )
    return _new(
        pkg_info = pkg_info,
        repo_name = repository_utils.package_name(repository_ctx),
        target_deps = target_deps,
        module_aliases = module_aliases,
        dep_module_aliases = dep_module_aliases,
    )

def _new(
        pkg_info,
        repo_name,
        target_deps = {},
        module_aliases = {},
        dep_module_aliases = ""):
    manual_target_deps.validate(pkg_info, target_deps)

    # A package's sources may import an aliased module under its original
    # name when the package renames the module itself or when a direct
    # dependency renames it (a package can only import modules from packages
    # that it declares directly). Collect the `-module-alias` mappings that
    # apply to this package's Swift targets. The package that renames a
    # module needs the alias as well: package sources commonly self-qualify
    # with their own module name.
    aliases_by_identity = json.decode(dep_module_aliases) if dep_module_aliases else {}
    module_alias_flags = dict(module_aliases)
    for dep in pkg_info.dependencies:
        module_alias_flags.update(aliases_by_identity.get(dep.identity, {}))

    return struct(
        pkg_info = pkg_info,
        repo_name = repo_name,
        target_deps = target_deps,
        module_aliases = module_aliases,
        module_alias_flags = module_alias_flags,
    )

pkg_ctxs = struct(
    new = _new,
    read = _read,
)
