"""Implementation for `swift_deps` bzlmod extension."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
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

def _declare_pkgs_from_package(module_ctx, from_package, config_pkgs, config_swift_package):
    """Declare Swift packages from `Package.swift` and `Package.resolved`.

    Args:
        module_ctx: An instance of `module_ctx`.
        from_package: The data from the `from_package` tag.
        config_pkgs: The data from the `configure_package` tag.
        config_swift_package: The data from the `configure_swift_package` tag.
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

    # Write info about the Swift deps that may be used by external tooling.
    if from_package.declare_swift_deps_info:
        swift_deps_info_repo_name = "swift_deps_info"
        swift_deps_info(
            name = swift_deps_info_repo_name,
            direct_dep_pkg_infos = direct_dep_pkg_infos,
        )
        direct_dep_repo_names.append(swift_deps_info_repo_name)

    if from_package.declare_swift_package:
        swift_package_repo_name = "swift_package"
        _declare_swift_package_repo(
            name = swift_package_repo_name,
            from_package = from_package,
            config_swift_package = config_swift_package,
        )
        direct_dep_repo_names.append(swift_package_repo_name)

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

    # Declare the Bazel repositories.
    for dep in all_deps_by_id.values():
        config_pkg = config_pkgs.get(dep.name)
        if config_pkg == None:
            config_pkg = config_pkgs.get(
                bazel_repo_names.from_identity(dep.identity),
            )
        _declare_pkg_from_dependency(dep, config_pkg, from_package, config_swift_package)

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
        registries = from_package.registries,
        **config_swift_package_kwargs
    )

def _swift_deps_impl(module_ctx):
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
    direct_dep_repo_names = []
    for mod in module_ctx.modules:
        for from_package in mod.tags.from_package:
            direct_dep_repo_names.extend(
                _declare_pkgs_from_package(
                    module_ctx,
                    from_package,
                    config_pkgs,
                    config_swift_package,
                ),
            )
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
