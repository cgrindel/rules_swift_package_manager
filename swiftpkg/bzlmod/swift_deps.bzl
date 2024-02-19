"""Implementation for `swift_deps` bzlmod extension."""

load("//swiftpkg/internal:bazel_repo_names.bzl", "bazel_repo_names")
load("//swiftpkg/internal:deps_indexes.bzl", "deps_indexes")
load("//swiftpkg/internal:local_swift_package.bzl", "local_swift_package")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:swift_package.bzl", "swift_package")

# MARK: - swift_deps bzlmod Extension

def _declare_pkg_from_package(package, deps_index_label, config_pkg):
    if package.remote_pkg != None:
        remote_pkg = package.remote_pkg
        init_submodules = None
        recursive_init_submodules = None
        if config_pkg:
            init_submodules = config_pkg.init_submodules
            recursive_init_submodules = config_pkg.recursive_init_submodules

        patch_args = None
        patch_cmds = None
        patch_cmds_win = None
        patch_tool = None
        patches = None
        patch = remote_pkg.patch
        if patch != None:
            patch_args = patch.args
            patch_cmds = patch.cmds
            patch_cmds_win = patch.win_cmds
            patch_tool = patch.tool
            patches = patch.files

        swift_package(
            name = package.name,
            bazel_package_name = package.name,
            commit = remote_pkg.commit,
            remote = remote_pkg.remote,
            dependencies_index = deps_index_label,
            init_submodules = init_submodules,
            recursive_init_submodules = recursive_init_submodules,
            patch_args = patch_args,
            patch_cmds = patch_cmds,
            patch_cmds_win = patch_cmds_win,
            patch_tool = patch_tool,
            patches = patches,
        )
    elif package.local_pkg != None:
        local_swift_package(
            name = package.name,
            bazel_package_name = package.name,
            path = package.local_pkg.path,
            dependencies_index = deps_index_label,
        )
    else:
        fail("Found package '{}' without a remote or local.".format(
            package.identity,
        ))

def _declare_pkgs_from_file(module_ctx, from_file, config_pkgs):
    index_json = module_ctx.read(from_file.deps_index)
    deps_index = deps_indexes.new_from_json(index_json)
    for package in deps_index.packages_by_id.values():
        config_pkg = config_pkgs.get(package.name)
        _declare_pkg_from_package(package, from_file.deps_index, config_pkg)

def _declare_pkgs_from_package(module_ctx, from_package, config_pkgs):
    """Declare Swift packages from `Package.swift` and `Package.resolved`.

    Args:
        module_ctx: An instance of `module_ctx`.
        from_package: The data from the `from_package` tag.
        config_pkgs: The data from the `configure_package` tag.
    """

    # Read Package.resolved.
    pkg_resolved = module_ctx.path(from_package.resolved)
    resolved_pkg_json = module_ctx.read(pkg_resolved)
    resolved_pkg_map = json.decode(resolved_pkg_json)

    # Get the package info.
    pkg_swift = module_ctx.path(from_package.swift)
    debug_path = module_ctx.path(".")
    pkg_info = pkginfos.get(
        module_ctx,
        directory = str(pkg_swift.dirname),
        debug_path = str(debug_path),
        resolved_pkg_map = resolved_pkg_map,
        # repo_name = "",
    )

    # Collect all of the deps by identity
    all_deps_by_id = {
        dep.identity: dep
        for dep in pkg_info.dependencies
    }

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
                # repo_name = bazel_repo_names.from_identity(dep.identity),
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
        _declare_pkg_from_dependency(dep, config_pkg)

def _declare_pkg_from_dependency(dep, config_pkg):
    name = bazel_repo_names.from_identity(dep.identity)

    # DEBUG BEGIN
    print("*** CHUCK ----------")
    print("*** CHUCK name: ", name)
    print("*** CHUCK dep: ", dep)

    # DEBUG END
    if dep.source_control:
        init_submodules = None
        recursive_init_submodules = None
        if config_pkg:
            init_submodules = config_pkg.init_submodules
            recursive_init_submodules = config_pkg.recursive_init_submodules

        # TODO(chuck): Figure out how to plumb patch args.
        patch_args = None
        patch_cmds = None
        patch_cmds_win = None
        patch_tool = None
        patches = None

        # patch = remote_pkg.patch
        patch = None
        if patch != None:
            patch_args = patch.args
            patch_cmds = patch.cmds
            patch_cmds_win = patch.win_cmds
            patch_tool = patch.tool
            patches = patch.files

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
    for mod in module_ctx.modules:
        for from_package in mod.tags.from_package:
            _declare_pkgs_from_package(module_ctx, from_package, config_pkgs)
        for from_file in mod.tags.from_file:
            _declare_pkgs_from_file(module_ctx, from_file, config_pkgs)

_from_file_tag = tag_class(
    attrs = {
        "deps_index": attr.label(
            mandatory = True,
            doc = "A `swift_deps_index.json`.",
        ),
    },
    doc = "Load Swift packages from a file generated by the Gazelle extension.",
)

_from_package_tag = tag_class(
    attrs = {
        "resolved": attr.label(
            mandatory = True,
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
    attrs = {
        "init_submodules": attr.bool(
            default = False,
            doc = "Whether to clone submodules in the repository.",
        ),
        "name": attr.string(
            doc = "The Bazel repository name for the Swift package.",
            mandatory = True,
        ),
        "recursive_init_submodules": attr.bool(
            default = True,
            doc = "Whether to clone submodules recursively in the repository.",
        ),
    },
    doc = "Used to add or override settings for a particular Swift package.",
)

swift_deps = module_extension(
    implementation = _swift_deps_impl,
    tag_classes = {
        "configure_package": _configure_package_tag,
        "from_file": _from_file_tag,
        "from_package": _from_package_tag,
    },
)
