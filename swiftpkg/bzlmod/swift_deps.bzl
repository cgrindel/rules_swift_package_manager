"""Implementation for `swift_deps` bzlmod extension."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:versions.bzl", "versions")
load("//swiftpkg/internal:bazel_repo_names.bzl", "bazel_repo_names")
load("//swiftpkg/internal:local_swift_package.bzl", "local_swift_package")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:registry_swift_package.bzl", "registry_swift_package")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:swift_deps_info.bzl", "swift_deps_info")
load("//swiftpkg/internal:swift_package.bzl", "PATCH_ATTRS", "TOOL_ATTRS", "swift_package")
load("//swiftpkg/internal:swift_package_tool_attrs.bzl", "swift_package_tool_attrs")
load("//swiftpkg/internal:swift_package_tool_repo.bzl", "swift_package_tool_repo")

# MARK: - swift_deps bzlmod Extension

_DO_WHILE_RANGE = range(1000)

# MARK: - Version Comparison Helpers

def _get_dependency_version(dep):
    """Extract version string from a dependency.

    Args:
        dep: A dependency struct as returned by `pkginfos.new_dependency()`.

    Returns:
        The version string if available, otherwise `None`.
    """
    if dep.source_control and dep.source_control.pin and dep.source_control.pin.state:
        return dep.source_control.pin.state.version
    if dep.registry and dep.registry.pin and dep.registry.pin.state:
        return dep.registry.pin.state.version
    return None

def _is_local_package(dep):
    """Check if a dependency is a local (fileSystem) package.

    Args:
        dep: A dependency struct as returned by `pkginfos.new_dependency()`.

    Returns:
        `True` if the dependency is a local package, otherwise `False`.
    """
    return dep.file_system != None

def _compare_versions(v1, v2):
    """Compare two version strings using semantic versioning.

    Uses Minimal Version Selection (MVS) approach - selects highest version.

    Args:
        v1: First version string.
        v2: Second version string.

    Returns:
        -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2.
    """
    if v1 == v2:
        return 0
    # Use bazel_skylib versions module for comparison
    if versions.is_at_least(threshold = v1, version = v2):
        # v2 >= v1 and v1 != v2 (already checked above), so v2 > v1
        return -1
    else:
        # v2 < v1, so v1 > v2
        return 1

def _compare_dependencies(dep1, dep2):
    """Compare two dependencies to determine which should be selected.

    Uses the following priority:
    1. Local packages always win over remote packages
    2. For remote packages, highest version wins (MVS)
    3. If versions are equal or both None, prefer the first one

    Args:
        dep1: First dependency candidate struct.
        dep2: Second dependency candidate struct.

    Returns:
        -1 if dep1 < dep2 (dep2 should be selected), 0 if equal, 1 if dep1 > dep2 (dep1 should be selected).
    """
    is_local1 = _is_local_package(dep1.dep)
    is_local2 = _is_local_package(dep2.dep)

    # Local packages always win
    if is_local1 and not is_local2:
        return 1
    if is_local2 and not is_local1:
        return -1
    if is_local1 and is_local2:
        # Both are local - prefer first one
        return 0

    # Both are remote - compare versions
    v1 = _get_dependency_version(dep1.dep)
    v2 = _get_dependency_version(dep2.dep)
    return _compare_versions(v1, v2)


def _collect_dependencies_from_package(
    module_ctx,
    module,
    from_package,
    config_pkgs,
    config_swift_package):
    """Collect all Swift package dependencies from a `Package.swift` and `Package.resolved`.

    This function collects dependencies but does not declare repositories yet.
    This allows us to resolve duplicates across all modules before declaring.

    Args:
        module_ctx: An instance of `module_ctx`.
        module: The bazel_module object for tracking which module declared the dependency.
        from_package: The data from the `from_package` tag.
        config_pkgs: The data from the `configure_package` tag.
        config_swift_package: The data from the `configure_swift_package` tag.

    Returns:
        A tuple of (all_deps_list, direct_dep_repo_names_list) where:
        - all_deps_list: List of dependency candidate structs with all transitive deps
        - direct_dep_repo_names_list: List of bazel repo names for direct dependencies
    """

    # Read Package.resolved.
    if from_package.resolved:
        pkg_resolved = module_ctx.path(from_package.resolved)
        resolved_pkg_json = module_ctx.read(pkg_resolved)
        resolved_pkg_map = json.decode(resolved_pkg_json)
    else:
        resolved_pkg_map = dict()

    # If using Swift Package registries we must set any requested
    # flags and the config path for the registries JSON file.
    # NOTE: SPM does not have a flag for setting the exact file path
    # for the registry, instead we must use the parent directory as the
    # config path and SPM finds the registry configuration file there.
    if from_package.registries:
        registries_directory = module_ctx.path(from_package.registries).dirname
    else:
        registries_directory = None

    if config_swift_package:
        replace_scm_with_registry = \
            config_swift_package.replace_scm_with_registry
    else:
        replace_scm_with_registry = False

    # Set the environment variables for getting the package info.
    env = {}
    for (key, value) in from_package.env.items():
        env[key] = value
    for key in from_package.env_inherit:
        env[key] = module_ctx.getenv(key)

    # Get the package info.
    pkg_swift = module_ctx.path(from_package.swift)
    debug_path = module_ctx.path(".")
    pkg_info = pkginfos.get(
        module_ctx,
        directory = str(pkg_swift.dirname),
        env = env,
        debug_path = str(debug_path),
        resolved_pkg_map = resolved_pkg_map,
        collect_src_info = False,
        registries_directory = registries_directory,
        replace_scm_with_registry = replace_scm_with_registry,
    )

    # Collect all of the deps by identity
    all_deps_by_id = {
        dep.identity: dep
        for dep in pkg_info.dependencies
    }

    # Collect the direct dep repo names
    direct_dep_repo_names = []
    direct_dep_pkg_infos = {}
    for dep in pkg_info.dependencies:
        # Ignore unresolved dependencies, for example for a new packgage added
        # to the `Package.swift` which has not been resolved yet.
        # By ignoring these for now we can allow the build to progress while
        # expecting a resolution in the future.
        if not dep.file_system and \
           (not dep.source_control or not dep.source_control.pin) and \
           (not dep.registry or not dep.registry.pin):
            # buildifier: disable=print
            print("""
WARNING: {name} is unresolved and won't be available during the build, resolve \
the Swift package to make it available.\
""".format(name = dep.name))
            continue

        bazel_repo_name = bazel_repo_names.from_identity(dep.identity)
        direct_dep_repo_names.append(bazel_repo_name)
        pkg_info_label = "@{}//:pkg_info.json".format(bazel_repo_name)
        direct_dep_pkg_infos[pkg_info_label] = dep.identity

    # Ensure that we add all of the transitive source control
    # or registry deps from the resolved file.
    for pin_map in resolved_pkg_map.get("pins", []):
        pin = pkginfos.new_pin_from_resolved_dep_map(pin_map)
        dep = all_deps_by_id.get(pin.identity)
        if dep != None:
            continue
        if pin.kind == "registry":
            dep = pkginfos.new_dependency(
                identity = pin.identity,
                name = pin.identity,
                registry = pkginfos.new_registry(pin = pin),
            )
        else:
            dep = pkginfos.new_dependency(
                identity = pin.identity,
                # Just use the identity for the name as we just need this to set
                # up the repositories.
                name = pin.identity,
                source_control = pkginfos.new_source_control(pin = pin),
            )
        all_deps_by_id[dep.identity] = dep

    if from_package.resolve_transitive_local_dependencies:
        # Find all of the local Swift packages and add them to the all_deps_by_id.
        # A local Swift package can reference other local Swift packages. Hence, we
        # need to check all of the transitive local Swift packages, not just the
        # direct local packages. We do not need to worry about the source control
        # deps because they are already listed in the Package.resolved.
        to_process = [
            dep
            for dep in all_deps_by_id.values()
            if dep.file_system
        ]
        for _ in _DO_WHILE_RANGE:
            if not to_process:
                break
            processing = to_process
            to_process = []
            for dep in processing:
                dep_pkg_info = pkginfos.get(
                    module_ctx,
                    directory = dep.file_system.path,
                    debug_path = None,
                    resolved_pkg_map = None,
                    collect_src_info = False,
                )
                fs_deps = [
                    d
                    for d in dep_pkg_info.dependencies
                    if d.file_system
                ]
                for fs_dep in fs_deps:
                    # Add any local Swift packages that we have not already found.
                    # Be sure to process them, as well.
                    if all_deps_by_id.get(fs_dep.identity) == None:
                        all_deps_by_id[fs_dep.identity] = fs_dep
                        to_process.append(fs_dep)
        if to_process:
            fail("Expected no more items to process, but found some.")

    # Create dependency candidates for all dependencies
    all_dep_candidates = []
    for dep in all_deps_by_id.values():
        bazel_repo_name = bazel_repo_names.from_identity(dep.identity)
        config_pkg = config_pkgs.get(dep.name)
        if config_pkg == None:
            config_pkg = config_pkgs.get(bazel_repo_name)
        dep_candidate = struct(
            dep = dep,
            bazel_repo_name = bazel_repo_name,
            config_pkg = config_pkg,
            from_package = from_package,
            config_swift_package = config_swift_package,
            module = module,
            direct_dep = bazel_repo_name in direct_dep_repo_names,
            publicly_expose_all_targets = config_pkg and config_pkg.publicly_expose_all_targets or False,
        )
        all_dep_candidates.append(dep_candidate)

    return (all_dep_candidates, direct_dep_repo_names)

def _resolve_duplicate_dependencies(all_dep_candidates, check_direct_dependencies, root_module_declared_versions):
    """Resolve duplicate dependencies by selecting the best version.

    Uses Minimal Version Selection (MVS) - selects highest version.
    Local packages always take precedence over remote packages.

    Args:
        all_dep_candidates: List of all dependency candidate structs from all modules.
        check_direct_dependencies: Boolean indicating whether to check version conflicts.
        root_module_declared_versions: Dict mapping bazel_repo_name to version string
            for dependencies declared in the root module.

    Returns:
        A dict mapping bazel_repo_name to the selected dependency candidate.
    """
    # Group dependencies by repository name
    deps_by_repo_name = {}
    for candidate in all_dep_candidates:
        repo_name = candidate.bazel_repo_name
        if repo_name not in deps_by_repo_name:
            deps_by_repo_name[repo_name] = []
        deps_by_repo_name[repo_name].append(candidate)

    # Resolve duplicates
    resolved_deps = {}
    for repo_name, candidates in deps_by_repo_name.items():
        if len(candidates) == 1:
            # No duplicates, use the single candidate
            resolved_deps[repo_name] = candidates[0]
        else:
            # Multiple candidates - resolve duplicates using MVS
            selected = candidates[0]
            for candidate in candidates[1:]:
                comparison = _compare_dependencies(selected, candidate)
                if comparison < 0:
                    # candidate is better than selected
                    selected = candidate

            resolved_deps[repo_name] = selected

    # Check for version mismatches for root module direct dependencies only
    if check_direct_dependencies:
        for repo_name, declared_version in root_module_declared_versions.items():
            resolved_candidate = resolved_deps.get(repo_name)
            if resolved_candidate == None:
                continue
            resolved_version = _get_dependency_version(resolved_candidate.dep)
            if resolved_version and declared_version and resolved_version != declared_version:
                fail("""
For repository '{repo}', root module declared {repo}@{declared} but {repo}@{resolved} \
from '{resolved_module}' was selected in the resolved dependency graph. \
To fix: Update your Package.swift to use version >= {resolved}, or set check_direct_dependencies = False.
""".format(
                    repo = repo_name,
                    declared = declared_version,
                    resolved = resolved_version,
                    resolved_module = resolved_candidate.module.name,
                ))

    return resolved_deps

def _declare_resolved_dependencies(resolved_deps):
    """Declare Bazel repositories for resolved dependencies.

    Args:
        resolved_deps: Dict mapping bazel_repo_name to selected dependency candidate.
    """
    for candidate in resolved_deps.values():
        _declare_pkg_from_dependency(
            candidate.dep,
            candidate.config_pkg,
            candidate.from_package,
            candidate.config_swift_package,
        )

def _declare_pkg_from_dependency(dep, config_pkg, from_package, config_swift_package):
    name = bazel_repo_names.from_identity(dep.identity)
    if dep.source_control:
        init_submodules = None
        recursive_init_submodules = None
        patch_args = None
        patch_cmds = None
        patch_cmds_win = None
        patch_tool = None
        patches = None
        publicly_expose_all_targets = None
        if config_pkg:
            init_submodules = config_pkg.init_submodules
            recursive_init_submodules = config_pkg.recursive_init_submodules
            patch_args = config_pkg.patch_args
            patch_cmds = config_pkg.patch_cmds
            patch_cmds_win = config_pkg.patch_cmds_win
            patch_tool = config_pkg.patch_tool
            patches = config_pkg.patches
            publicly_expose_all_targets = config_pkg.publicly_expose_all_targets

        registries = from_package.registries
        replace_scm_with_registry = False
        if config_swift_package:
            replace_scm_with_registry = \
                config_swift_package.replace_scm_with_registry

        pin = dep.source_control.pin
        swift_package(
            name = name,
            bazel_package_name = name,
            commit = pin.state.revision,
            remote = pin.location,
            version = pin.state.version,
            dependencies_index = None,
            env = from_package.env,
            env_inherit = from_package.env_inherit,
            init_submodules = init_submodules,
            recursive_init_submodules = recursive_init_submodules,
            netrc = from_package.netrc,
            patch_args = patch_args,
            patch_cmds = patch_cmds,
            patch_cmds_win = patch_cmds_win,
            patch_tool = patch_tool,
            patches = patches,
            publicly_expose_all_targets = publicly_expose_all_targets,
            registries = registries,
            replace_scm_with_registry = replace_scm_with_registry,
        )

    elif dep.file_system:
        local_swift_package(
            name = name,
            bazel_package_name = name,
            env = from_package.env,
            env_inherit = from_package.env_inherit,
            path = dep.file_system.path,
            dependencies_index = None,
        )

    elif dep.registry:
        resolved = from_package.resolved if from_package else None
        replace_scm_with_registry = False
        if config_swift_package:
            replace_scm_with_registry = config_swift_package.replace_scm_with_registry

        registry_swift_package(
            name = name,
            bazel_package_name = name,
            env = from_package.env,
            env_inherit = from_package.env_inherit,
            id = dep.registry.pin.identity,
            registries = from_package.registries,
            replace_scm_with_registry = replace_scm_with_registry,
            resolved = resolved,
            version = dep.registry.pin.state.version,
        )

def _declare_swift_package_repo(name, from_package, config_swift_package):
    config_swift_package_kwargs = repository_utils.struct_to_kwargs(
        struct = config_swift_package,
        keys = swift_package_tool_attrs.swift_package_tool_config,
    )

    swift_package_tool_repo(
        name = name,
        env = from_package.env,
        package = "{package}/{name}".format(
            package = from_package.swift.package,
            name = from_package.swift.name,
        ),
        netrc = from_package.netrc,
        registries = from_package.registries,
        **config_swift_package_kwargs
    )

def _swift_deps_impl(module_ctx):
    # Collect configuration
    config_pkgs = {}
    for mod in module_ctx.modules:
        for config_pkg in mod.tags.configure_package:
            config_pkgs[config_pkg.name] = config_pkg
    config_swift_package = None
    for mod in module_ctx.modules:
        for config_swift_package_tag in mod.tags.configure_swift_package:
            if config_swift_package:
                fail("""\
Expected only one `configure_swift_package` tag, but found multiple.\
""")
            config_swift_package = config_swift_package_tag

    # Phase 1: Collect all dependencies from all modules
    all_dep_candidates = []
    root_module_direct_dep_repo_names = []
    root_module_declared_versions = {}  # Track declared versions for root module dependencies
    root_declare_swift_deps_info = False
    root_declare_swift_package = False
    swift_deps_info_repos = []
    swift_package_repos = []
    check_direct_dependencies = False

    for mod in module_ctx.modules:
        for from_package in mod.tags.from_package:
            # Enable checking if the root module enables it
            if mod.is_root and from_package.check_direct_dependencies:
                check_direct_dependencies = True

            # Collect dependencies from this module
            (module_dep_candidates, module_direct_dep_repo_names) = _collect_dependencies_from_package(
                module_ctx,
                mod,
                from_package,
                config_pkgs,
                config_swift_package,
            )
            all_dep_candidates.extend(module_dep_candidates)
            # Track root module direct dependencies and their declared versions
            if mod.is_root:
                root_module_direct_dep_repo_names.extend(module_direct_dep_repo_names)
                # Store declared versions for root module direct dependencies
                # (versions are already captured in module_dep_candidates)
                for candidate in module_dep_candidates:
                    if candidate.direct_dep:
                        version = _get_dependency_version(candidate.dep)
                        if version:
                            root_module_declared_versions[candidate.bazel_repo_name] = version
                # Track root module's declaration flags
                if from_package.declare_swift_deps_info:
                    root_declare_swift_deps_info = True
                if from_package.declare_swift_package:
                    root_declare_swift_package = True

            # Handle swift_deps_info and swift_package repositories
            if from_package.declare_swift_deps_info:
                # Collect direct dep pkg infos for this module
                direct_dep_pkg_infos = {}
                for candidate in module_dep_candidates:
                    if candidate.direct_dep:
                        pkg_info_label = "@{}//:pkg_info.json".format(candidate.bazel_repo_name)
                        direct_dep_pkg_infos[pkg_info_label] = candidate.dep.identity
                swift_deps_info_repos.append((from_package, direct_dep_pkg_infos))

            if from_package.declare_swift_package:
                swift_package_repos.append((from_package, config_swift_package))

    # Phase 2: Resolve duplicates
    resolved_deps = _resolve_duplicate_dependencies(all_dep_candidates, check_direct_dependencies, root_module_declared_versions)

    # Phase 3: Declare repositories
    _declare_resolved_dependencies(resolved_deps)

    # Declare swift_deps_info repository (only once, prefer root module)
    if swift_deps_info_repos:
        # Merge direct_dep_pkg_infos from all modules
        merged_direct_dep_pkg_infos = {}
        for (_, direct_dep_pkg_infos) in swift_deps_info_repos:
            merged_direct_dep_pkg_infos.update(direct_dep_pkg_infos)
        swift_deps_info_repo_name = "swift_deps_info"
        swift_deps_info(
            name = swift_deps_info_repo_name,
            direct_dep_pkg_infos = merged_direct_dep_pkg_infos,
        )

    # Declare swift_package repository (only once, prefer root module)
    if swift_package_repos:
        # Use the first one (typically root module)
        (from_package_for_repo, config_swift_package_for_repo) = swift_package_repos[0]
        swift_package_repo_name = "swift_package"
        _declare_swift_package_repo(
            name = swift_package_repo_name,
            from_package = from_package_for_repo,
            config_swift_package = config_swift_package_for_repo,
        )

    # Build final direct_dep_repo_names list - only root module direct dependencies
    direct_dep_repo_names = []

    # Add root module direct dependencies that are resolved
    for repo_name in root_module_direct_dep_repo_names:
        if repo_name in resolved_deps:
            direct_dep_repo_names.append(repo_name)

    # Add transitive dependencies if publicly_expose_all_targets is set
    for candidate in resolved_deps.values():
        if candidate.publicly_expose_all_targets:
            repo_name = candidate.bazel_repo_name
            if repo_name not in direct_dep_repo_names:
                direct_dep_repo_names.append(repo_name)

    # Add swift_deps_info and swift_package if declared by root module
    if root_declare_swift_deps_info:
        direct_dep_repo_names.append("swift_deps_info")
    if root_declare_swift_package:
        direct_dep_repo_names.append("swift_package")

    return module_ctx.extension_metadata(
        root_module_direct_deps = direct_dep_repo_names,
        root_module_direct_dev_deps = [],
    )

_from_package_tag = tag_class(
    attrs = dicts.add(
        swift_package_tool_attrs.swift_package_registry,
        {
            "declare_swift_deps_info": attr.bool(
                doc = """\
Declare a `swift_deps_info` repository that is used by external tooling (e.g. \
Swift Gazelle plugin).\
""",
            ),
            "declare_swift_package": attr.bool(
                default = True,
                doc = """\
Declare a `swift_package_tool` repository named `swift_package` which defines two targets:
`update` and `resolve`.\

These targets run can be used to run the `swift package` binary in a Bazel context.
The flags used when running the underlying `swift package` can be configured \
using the `configure_swift_package` tag.

They can be `bazel run` to update/resolve the `resolved` file:

```
bazel run @swift_package//:update
bazel run @swift_package//:resolve
```
""",
            ),
            "env": attr.string_dict(
                doc = """\
Environment variables that will be passed to the execution environments for \
this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM \
package description generation)\
""",
            ),
            "env_inherit": attr.string_list(
                doc = """\
Environment variables to inherit from the external environment that will be \
passed to the execution environments for this repository rule. (e.g. SPM version check, \
SPM dependency resolution, SPM package description generation)\
""",
            ),
            "resolve_transitive_local_dependencies": attr.bool(
                default = True,
                doc = """\
Local Swift packages that are declared directly in the `Package.swift` file can depend on other \
local packages. By default these transitive dependencies will be automatically resolved and \
made available during the build process.

The process of resolving transitive local dependencies can become time consuming as the number \
of local Swift packages grows. Setting this flag to `False` will skip resolving local packages \
and instead require every local Swift package that is required during the build to be explicitly \
defined in the `Package.swift` file.

This time appears as `Fetching module extension swift_deps in @@rules_swift_package_manager~//:extensions.bzl;` \
in the output log.
""",
            ),
            "resolved": attr.label(
                allow_files = [".resolved"],
                doc = "A `Package.resolved`.",
            ),
            "swift": attr.label(
                mandatory = True,
                allow_files = [".swift"],
                doc = "A `Package.swift`.",
            ),
            "check_direct_dependencies": attr.bool(
                default = True,
                doc = """\
Check if the direct dependencies declared in the root module match the versions in the \
resolved dependency graph. When enabled, the build will fail if the root module's \
Package.resolved contains different versions than what MVS selected. Defaults to True.\
""",
            ),
        },
    ),
    doc = "Load Swift packages from `Package.swift` and `Package.resolved` files.",
)

_configure_package_tag = tag_class(
    attrs = {
        "init_submodules": attr.bool(
            default = False,
            doc = "Whether to clone submodules in the repository.",
        ),
        "name": attr.string(
            doc = """\
The identity (i.e., name in the package's manifest) for the Swift package.\
""",
            mandatory = True,
        ),
        "recursive_init_submodules": attr.bool(
            default = True,
            doc = "Whether to clone submodules recursively in the repository.",
        ),
    } | PATCH_ATTRS | TOOL_ATTRS,
    doc = "Used to add or override settings for a particular Swift package.",
)

_configure_swift_package_tag = tag_class(
    attrs = swift_package_tool_attrs.swift_package_tool_config,
    doc = "Used to configure the flags used when running the `swift package` binary.",
)

swift_deps = module_extension(
    implementation = _swift_deps_impl,
    tag_classes = {
        "configure_package": _configure_package_tag,
        "configure_swift_package": _configure_swift_package_tag,
        "from_package": _from_package_tag,
    },
)
