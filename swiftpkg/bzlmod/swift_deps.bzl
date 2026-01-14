"""Implementation for `swift_deps` bzlmod extension."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//swiftpkg/internal:bazel_repo_names.bzl", "bazel_repo_names")
load("//swiftpkg/internal:local_swift_package.bzl", "local_swift_package")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:registry_swift_package.bzl", "registry_swift_package")
load("//swiftpkg/internal:repo_rules.bzl", "repo_rules")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:swift_deps_info.bzl", "swift_deps_info")
load("//swiftpkg/internal:swift_package.bzl", "PATCH_ATTRS", "TOOL_ATTRS", "swift_package")
load("//swiftpkg/internal:swift_package_files.bzl", "swift_package_files")
load("//swiftpkg/internal:swift_package_tool_attrs.bzl", "swift_package_tool_attrs")
load("//swiftpkg/internal:swift_package_tool_repo.bzl", "swift_package_tool_repo")

# MARK: - swift_deps bzlmod Extension

_DO_WHILE_RANGE = range(1000)

def _get_env(*, module_ctx, from_package):
    """Returns the environment variables as configured in the `from_package` tag.

    Args:
        module_ctx: An instance of `module_ctx`.
        from_package: The data from the `from_package` tag.

    Returns:
        A dictionary of environment variables.
    """

    env = {}
    for (key, value) in from_package.env.items():
        env[key] = value
    for key in from_package.env_inherit:
        env[key] = module_ctx.getenv(key)
    return env

def _declare_pkgs_from_package(
        module_ctx,
        from_package,
        config_pkgs,
        direct_dep_repo_names,
        resolved_pkg_map,
        all_deps_by_id):
    """Declare Swift packages from `Package.swift` and `Package.resolved`.

    Args:
        module_ctx: An instance of `module_ctx`.
        from_package: The data from the `from_package` tag.
        config_pkgs: The data from the `configure_package` tag.
        direct_dep_repo_names: The list of direct dependency repository names.
        resolved_pkg_map: The `Package.resolved` map.
        all_deps_by_id: The map of all dependencies by identity.
    """

    resolved_pkg_map = resolved_pkg_map or {}

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
                    replace_scm_with_registry = from_package.replace_scm_with_registry,
                    use_registry_identity_for_scm = from_package.use_registry_identity_for_scm,
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

    # Declare the Bazel repositories.
    for dep in all_deps_by_id.values():
        config_pkg = config_pkgs.get(dep.name)
        if config_pkg == None:
            config_pkg = config_pkgs.get(
                bazel_repo_names.from_identity(dep.identity),
            )
        _declare_pkg_from_dependency(dep, config_pkg, from_package)

    # Add all transitive dependencies to direct_dep_repo_names if `publicly_expose_all_targets` flag is set.
    for dep in all_deps_by_id.values():
        config_pkg = config_pkgs.get(dep.name) or config_pkgs.get(
            bazel_repo_names.from_identity(dep.identity),
        )
        if config_pkg and config_pkg.publicly_expose_all_targets:
            bazel_repo_name = bazel_repo_names.from_identity(dep.identity)
            if bazel_repo_name not in direct_dep_repo_names:
                direct_dep_repo_names.append(bazel_repo_name)

    return direct_dep_repo_names

def _declare_pkg_from_dependency(dep, config_pkg, from_package):
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
            registries = from_package.registries,
            replace_scm_with_registry = from_package.replace_scm_with_registry,
            use_registry_identity_for_scm = from_package.use_registry_identity_for_scm,
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

        registry_swift_package(
            name = name,
            bazel_package_name = name,
            env = from_package.env,
            env_inherit = from_package.env_inherit,
            id = dep.registry.pin.identity,
            registries = from_package.registries,
            replace_scm_with_registry = from_package.replace_scm_with_registry,
            resolved = resolved,
            use_registry_identity_for_scm = from_package.use_registry_identity_for_scm,
            version = dep.registry.pin.state.version,
        )

def _declare_swift_package_repo(
        name,
        package_content,
        package_path,
        config_swift_package,
        env,
        netrc,
        registries):
    config_swift_package_kwargs = repository_utils.struct_to_kwargs(
        struct = config_swift_package,
        keys = swift_package_tool_attrs.swift_package_tool_config,
    )

    swift_package_tool_repo(
        name = name,
        env = env,
        package_content = package_content,
        package_path = str(package_path),
        netrc = netrc,
        registries = registries,
        **config_swift_package_kwargs
    )

def _swift_deps_impl(module_ctx):
    all_deps_by_mod = {}
    config_pkgs = {}
    config_swift_package_map = {}
    debug_path = str(module_ctx.path("."))
    root_module = None
    root_module_direct_deps = []
    root_module_swift_tools_version = None
    from_package_map = {}

    # Collect the expected tags from all modules.
    for mod in module_ctx.modules:
        if not mod.name:
            fail("""\
Expected a module name in `swift_deps` extension, but found none. \
Declare the module name using the `module` directive in the MODULE.bazel file.
""")

        if mod.is_root:
            root_module = mod

        # Collect the configure_package tags.
        for config_pkg in mod.tags.configure_package:
            config_pkgs[config_pkg.name] = config_pkg

        # Collect the from_package tags.
        for from_package in mod.tags.from_package:
            from_package_map[mod.name] = from_package

        # Collect the `swift_package` repository configuration.
        for config_swift_package_tag in mod.tags.configure_swift_package:
            config_swift_package_map[mod.name] = config_swift_package_tag

    # Declare the repositories generate for each module.
    for mod in module_ctx.modules:
        from_package = from_package_map.get(mod.name)

        # Get the package info.
        pkg_swift = module_ctx.path(from_package.swift)
        pkg_info = pkginfos.get(
            module_ctx,
            directory = str(pkg_swift.dirname),
            env = _get_env(module_ctx = module_ctx, from_package = from_package),
            debug_path = debug_path,
            collect_src_info = False,
        )
        if mod.is_root:
            root_module_swift_tools_version = pkg_info.tools_version

        # Collect the direct dep pkg infos used in the swift_deps_info repository.
        direct_dep_pkg_infos = {}
        direct_dep_repo_names = []
        for dep in pkg_info.dependencies:
            bazel_repo_name = bazel_repo_names.from_identity(dep.identity)
            direct_dep_repo_names.append(bazel_repo_name)
            pkg_info_label = "@{}//:pkg_info.json".format(bazel_repo_name)
            direct_dep_pkg_infos[pkg_info_label] = dep.identity

        # Declare the "development" repositories, these must all have unique names (prefixed with the module name).
        # Otherwise, it would be impossible to depend on a Bazel module that also uses this extension.
        # These repositories are typically only intended for internal use but we cannot mark them as `dev_dependency`
        # because we'd duplicate the work required to dump the package info and for swift_package we would
        # be unable to "merge" the package manifests across modules since external modules wouldn't be in the module context.
        swift_deps_info_repo_name = "%s_swift_deps_info" % mod.name
        swift_package_repo_name = "%s_swift_package" % mod.name
        swift_deps_info(
            name = swift_deps_info_repo_name,
            direct_dep_pkg_infos = direct_dep_pkg_infos,
        )

        # Declare an empty swift_package repository for non-root modules, these should not be used directly.
        # The root module generates this repository using the merged `Package.swift` file.
        if mod.is_root:
            root_module_direct_deps.append(swift_deps_info_repo_name)
            root_module_direct_deps.append(swift_package_repo_name)
        else:
            repository_utils.declare_empty_repository(name = swift_package_repo_name)

        # Collect all of the deps by module name that declared them.
        if not mod.name in all_deps_by_mod:
            all_deps_by_mod[mod.name] = []
        all_deps_by_mod[mod.name].extend(pkg_info.dependencies)

    if not root_module or not from_package_map[root_module.name]:
        fail("Expected a root module and from_package for the root module, but found none.")

    # If the `Package.resolved` does not exist, the root module must resolve it first.
    resolved = from_package_map[root_module.name].resolved
    if resolved and module_ctx.path(resolved).exists:
        resolved_pkg_map = json.decode(module_ctx.read(module_ctx.path(resolved)))
    else:
        resolved_pkg_map = None

    # Collect the `Package.swift` files for all modules.
    # pkg_files = []
    # for mod in module_ctx.modules:
    #     from_package = from_package_map[mod.name]
    #     pkg_files.append(
    #         struct(
    #             name = mod.name,
    #             path = module_ctx.path(from_package.swift),
    #         ),
    #     )

    # Merge all of the `Package.swift` files into a single `Package.swift` file.
    merged_package_content = swift_package_files.merge(
        all_deps_by_mod = all_deps_by_mod,
        tools_version = root_module_swift_tools_version,
    )
    module_ctx.file("Package.swift", merged_package_content)
    merged_package_file = module_ctx.path("Package.swift")

    # Collect all dependencies from the "merged" `Package.swift` file.
    root_from_package = from_package_map[root_module.name]
    root_config_swift_package = config_swift_package_map.get(root_module.name)

    # Declare the swift_package repository for the root module.
    _declare_swift_package_repo(
        name = "{}_swift_package".format(root_module.name),
        package_content = merged_package_content,
        package_path = module_ctx.path(root_from_package.swift).dirname,
        env = _get_env(module_ctx = module_ctx, from_package = root_from_package),
        netrc = root_from_package.netrc,
        registries = root_from_package.registries,
        config_swift_package = root_config_swift_package,
    )

    # NOTE: SPM does not have a flag for setting the exact file path
    # for the registry, instead we must use the parent directory as the
    # config path and SPM finds the registry configuration file there.
    if root_from_package.registries:
        registries_directory = module_ctx.path(root_from_package.registries).dirname
    else:
        registries_directory = None

    merged_pkg_info = pkginfos.get(
        module_ctx,
        directory = str(merged_package_file.dirname),
        env = _get_env(module_ctx = module_ctx, from_package = root_from_package),
        debug_path = debug_path,
        collect_src_info = False,
        resolved_pkg_map = resolved_pkg_map,
        registries_directory = registries_directory,
        replace_scm_with_registry = root_from_package.replace_scm_with_registry,
        use_registry_identity_for_scm = root_from_package.use_registry_identity_for_scm,
    )

    direct_dep_repo_names = []
    for dep in merged_pkg_info.dependencies:
        bazel_repo_name = bazel_repo_names.from_identity(dep.identity)
        if not bazel_repo_name in direct_dep_repo_names:
            direct_dep_repo_names.append(bazel_repo_name)

    # TODO: Implement handling resolved_pkg_map and declaring the real repositories.
    # Declare empty repositories for all of the direct dependencies.
    for repo_name in direct_dep_repo_names:
        repository_utils.declare_empty_repository(name = repo_name)

    root_module_direct_deps.extend(direct_dep_repo_names)

    return module_ctx.extension_metadata(
        root_module_direct_deps = root_module_direct_deps,
        root_module_direct_dev_deps = [],
    )

_from_package_tag = tag_class(
    attrs = dicts.add(
        repo_rules.env_attrs,
        repo_rules.netrc_attrs,
        swift_package_tool_attrs.swift_package_registry,
        {
            "declare_swift_deps_info": attr.bool(
                default = False,
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
