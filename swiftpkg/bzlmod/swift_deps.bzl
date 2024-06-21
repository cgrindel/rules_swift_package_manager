"""Implementation for `swift_deps` bzlmod extension."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//swiftpkg/internal:bazel_repo_names.bzl", "bazel_repo_names")
load("//swiftpkg/internal:local_swift_package.bzl", "local_swift_package")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:swift_deps_info.bzl", "swift_deps_info")
load("//swiftpkg/internal:swift_package.bzl", "PATCH_ATTRS", "swift_package")

# MARK: - swift_deps bzlmod Extension

def _declare_pkgs_from_package(module_ctx, from_package, config_pkgs):
    """Declare Swift packages from `Package.swift` and `Package.resolved`.

    Args:
        module_ctx: An instance of `module_ctx`.
        from_package: The data from the `from_package` tag.
        config_pkgs: The data from the `configure_package` tag.
    """

    # Read Package.resolved.
    if from_package.resolved:
        pkg_resolved = module_ctx.path(from_package.resolved)
        resolved_pkg_json = module_ctx.read(pkg_resolved)
        resolved_pkg_map = json.decode(resolved_pkg_json)
    else:
        resolved_pkg_map = dict()

    # Get the package info.
    pkg_swift = module_ctx.path(from_package.swift)
    debug_path = module_ctx.path(".")
    pkg_info = pkginfos.get(
        module_ctx,
        directory = str(pkg_swift.dirname),
        debug_path = str(debug_path),
        resolved_pkg_map = resolved_pkg_map,
        collect_src_info = False,
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
        bazel_repo_name = bazel_repo_names.from_identity(dep.identity)
        direct_dep_repo_names.append(bazel_repo_name)
        pkg_info_label = "@{}//:pkg_info.json".format(bazel_repo_name)
        direct_dep_pkg_infos[pkg_info_label] = dep.identity

    # Write info about the Swift deps that may be used by external tooling.
    swift_deps_info_repo_name = "swift_deps_info"
    swift_deps_info(
        name = swift_deps_info_repo_name,
        direct_dep_pkg_infos = direct_dep_pkg_infos,
    )
    direct_dep_repo_names.append(swift_deps_info_repo_name)

    # Ensure that we add all of the transitive source control deps from the
    # resolved file.
    for pin_map in resolved_pkg_map.get("pins", []):
        pin = pkginfos.new_pin_from_resolved_dep_map(pin_map)
        dep = all_deps_by_id.get(pin.identity)
        if dep != None:
            continue
        dep = pkginfos.new_dependency(
            identity = pin.identity,
            # Just use the identity for the name as we just need this to set
            # up the repositories.
            name = pin.identity,
            source_control = pkginfos.new_source_control(pin = pin),
        )
        all_deps_by_id[dep.identity] = dep

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
    for _ in range(100):
        if len(to_process) == 0:
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

    # Declare the Bazel repositories.
    for dep in all_deps_by_id.values():
        config_pkg = config_pkgs.get(dep.name)
        if config_pkg == None:
            config_pkg = config_pkgs.get(
                bazel_repo_names.from_identity(dep.identity),
            )
        _declare_pkg_from_dependency(dep, config_pkg)

    return direct_dep_repo_names

def _declare_pkg_from_dependency(dep, config_pkg):
    name = bazel_repo_names.from_identity(dep.identity)
    if dep.source_control:
        init_submodules = None
        recursive_init_submodules = None
        patch_args = None
        patch_cmds = None
        patch_cmds_win = None
        patch_tool = None
        patches = None
        if config_pkg:
            init_submodules = config_pkg.init_submodules
            recursive_init_submodules = config_pkg.recursive_init_submodules
            patch_args = config_pkg.patch_args
            patch_cmds = config_pkg.patch_cmds
            patch_cmds_win = config_pkg.patch_cmds_win
            patch_tool = config_pkg.patch_tool
            patches = config_pkg.patches

        pin = dep.source_control.pin
        swift_package(
            name = name,
            bazel_package_name = name,
            commit = pin.state.revision,
            remote = pin.location,
            dependencies_index = None,
            init_submodules = init_submodules,
            recursive_init_submodules = recursive_init_submodules,
            patch_args = patch_args,
            patch_cmds = patch_cmds,
            patch_cmds_win = patch_cmds_win,
            patch_tool = patch_tool,
            patches = patches,
        )

    elif dep.file_system:
        local_swift_package(
            name = name,
            bazel_package_name = name,
            path = dep.file_system.path,
            dependencies_index = None,
        )

    else:
        fail("Unrecognized dependency type for {}.".format(dep.identity))

def _swift_deps_impl(module_ctx):
    config_pkgs = {}
    for mod in module_ctx.modules:
        for config_pkg in mod.tags.configure_package:
            config_pkgs[config_pkg.name] = config_pkg
    direct_dep_repo_names = []
    for mod in module_ctx.modules:
        for from_package in mod.tags.from_package:
            direct_dep_repo_names.extend(
                _declare_pkgs_from_package(
                    module_ctx,
                    from_package,
                    config_pkgs,
                ),
            )
    return module_ctx.extension_metadata(
        root_module_direct_deps = direct_dep_repo_names,
        root_module_direct_dev_deps = [],
    )

_from_package_tag = tag_class(
    attrs = {
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
    doc = "Load Swift packages from a `Package.swift` and `Package.resolved`.",
)

_configure_package_tag = tag_class(
    attrs = dicts.add({
        "init_submodules": attr.bool(
            default = False,
            doc = "Whether to clone submodules in the repository.",
        ),
        "name": attr.string(
            doc = "The Bazel repository name for the Swift package.",
            mandatory = True,
        ),
        "recursive_init_submodules": attr.bool(
            default = False,
            doc = "Whether to clone submodules recursively in the repository.",
        ),
    }, PATCH_ATTRS),
    doc = "Used to add or override settings for a particular Swift package.",
)

swift_deps = module_extension(
    implementation = _swift_deps_impl,
    tag_classes = {
        "configure_package": _configure_package_tag,
        "from_package": _from_package_tag,
    },
)
