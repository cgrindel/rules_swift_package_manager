"""Module for creating a module index context for a package info."""

load(":bazel_repo_names.bzl", "bazel_repo_names")
load(":manual_target_deps.bzl", "manual_target_deps")
load(":minimum_os_versions.bzl", "minimum_os_versions")
load(":pkginfo_dependencies.bzl", "pkginfo_dependencies")
load(":pkginfos.bzl", "pkginfos", "target_types")
load(":repository_utils.bzl", "repository_utils")

# Written to the root of every generated package repository. Holds the
# package's effective minimum OS versions per platform (declared floors raised
# to satisfy dependencies) for each product and for the package as a whole, so
# that dependent package repositories can raise their own floors in turn.
_MINIMUM_OS_VERSIONS_FILE = "minimum_os_versions.json"

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
    pkg_ctx = _new(
        pkg_info = pkg_info,
        repo_name = repository_utils.package_name(repository_ctx),
        target_deps = target_deps,
        module_aliases = module_aliases,
        dep_module_aliases = dep_module_aliases,
        dep_minimum_os_versions = _read_dep_minimum_os_versions(
            repository_ctx,
            pkg_info,
        ),
    )
    repository_ctx.file(
        _MINIMUM_OS_VERSIONS_FILE,
        content = json.encode_indent(
            minimum_os_versions.new_exported(pkg_ctx.minimum_os_versions),
            indent = "  ",
        ),
        executable = False,
    )
    return pkg_ctx

def _new(
        pkg_info,
        repo_name,
        target_deps = {},
        module_aliases = {},
        dep_module_aliases = "",
        dep_minimum_os_versions = {}):
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
        # Effective minimum OS versions per target, product and package. See
        # `minimum_os_versions.for_targets`.
        minimum_os_versions = minimum_os_versions.for_targets(
            pkg_info,
            dep_minimum_os_versions,
        ),
    )

def _referenced_dependency_identities(pkg_info):
    """Identities of the external packages used by this package's built targets.

    Test targets are skipped because they are not generated (their external
    dependencies may not even be resolved). Mirrors the resolution performed
    by `pkginfo_target_deps` for product and by-name references.

    Args:
        pkg_info: A `struct` as returned by `pkginfos.new`.

    Returns:
        A sorted `list` of package identity `string` values.
    """
    local_names = [t.name for t in pkg_info.targets] + [p.name for p in pkg_info.products]
    identities = {}
    for target in pkg_info.targets:
        if target.type == target_types.test:
            continue
        for target_dep in target.dependencies:
            dep_name = None
            if target_dep.product:
                if target_dep.product.dep_name == pkg_info.name:
                    continue
                dep_name = target_dep.product.dep_name
            elif target_dep.by_name:
                if target_dep.by_name.name in local_names:
                    continue
                dep_name = target_dep.by_name.name
            if dep_name == None:
                continue
            dep = pkginfo_dependencies.get_by_name(pkg_info.dependencies, dep_name)
            if dep != None:
                identities[dep.identity] = None
    return sorted(identities.keys())

def _read_dep_minimum_os_versions(repository_ctx, pkg_info):
    """Reads the effective minimum OS versions of this package's dependencies.

    Dependency repositories are declared by the same module extension as this
    repository, so they share its canonical name prefix. Only repositories
    listed in the `package_repos` file are read: referencing an undeclared
    repository fails the fetch, and a dependency can legitimately be absent
    (e.g. pruned from `Package.resolved` by SwiftPM's target-based
    resolution). Repositories without the versions file (unresolved
    placeholders) contribute nothing.

    Args:
        repository_ctx: A `repository_ctx`.
        pkg_info: A `struct` as returned by `pkginfos.new`.

    Returns:
        A `dict` mapping dependency identities to the `dict` each dependency
        exported (see `minimum_os_versions.new_exported`).
    """
    package_repos_label = getattr(repository_ctx.attr, "package_repos", None)
    if package_repos_label == None:
        return {}
    declared_repo_names = json.decode(
        repository_ctx.read(package_repos_label),
    ).get("repo_names", [])

    package_name = repository_utils.package_name(repository_ctx)
    canonical_name = repository_ctx.name
    if not canonical_name.endswith(package_name):
        fail("""\
Expected the canonical repository name '{canonical}' to end with the package \
repository name '{name}'.\
""".format(canonical = canonical_name, name = package_name))
    canonical_prefix = canonical_name[:len(canonical_name) - len(package_name)]

    dep_versions = {}
    for identity in _referenced_dependency_identities(pkg_info):
        dep_repo_name = bazel_repo_names.from_identity(identity)
        if dep_repo_name not in declared_repo_names:
            continue
        label = Label("@@{prefix}{repo}//:{file}".format(
            prefix = canonical_prefix,
            repo = dep_repo_name,
            file = _MINIMUM_OS_VERSIONS_FILE,
        ))
        if not repository_ctx.path(label).exists:
            continue
        dep_versions[identity] = json.decode(repository_ctx.read(label))
    return dep_versions

pkg_ctxs = struct(
    new = _new,
    read = _read,
    referenced_dependency_identities = _referenced_dependency_identities,
)
