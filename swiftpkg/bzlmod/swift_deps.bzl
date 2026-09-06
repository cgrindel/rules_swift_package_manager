"""Implementation for `swift_deps` bzlmod extension."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("//swiftpkg/internal:bazel_repo_names.bzl", "bazel_repo_names")
load("//swiftpkg/internal:bazel_target_mods.bzl", "bazel_target_mods")
load("//swiftpkg/internal:local_swift_package.bzl", "local_swift_package")
load("//swiftpkg/internal:pkginfo_dependencies.bzl", "pkginfo_dependencies")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:registry_swift_package.bzl", "registry_swift_package")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:swift_deps_info.bzl", "swift_deps_info")
load("//swiftpkg/internal:swift_package.bzl", "PATCH_ATTRS", "TOOL_ATTRS", "swift_package")
load("//swiftpkg/internal:swift_package_tool_attrs.bzl", "swift_package_tool_attrs")
load("//swiftpkg/internal:swift_package_tool_repo.bzl", "swift_package_tool_repo")

# MARK: - swift_deps bzlmod Extension

_DO_WHILE_RANGE = range(1000)

def _module_aliases_by_identity(pkg_info):
    """Collect module aliases declared in the root package manifest (SE-0339).

    Collects the `moduleAliases` declared on product dependencies of the root
    package's targets, keyed by the identity of the package that provides the
    aliased product. Scoping the aliases to the providing package ensures a
    same-named module from a different package is unaffected: only the
    providing package renames its module, and only that package and its
    direct dependents compile with `-module-alias` flags. Aliases declared by
    non-root packages in the dependency graph are not yet supported.

    Only pure Swift, source-based modules may be aliased (an SE-0339
    restriction); aliasing a module with C/Objective-C interop or a binary
    target is not supported and will fail to build.

    Args:
        pkg_info: A `struct` as returned by `pkginfos.get` for the root
            package.

    Returns:
        A `dict` mapping package identities to a `dict` of original module
        names to their replacement names.
    """
    aliases_by_identity = {}
    for target in pkg_info.targets:
        for target_dep in target.dependencies:
            product = target_dep.product
            if not (product and product.module_aliases):
                continue
            dep = pkginfo_dependencies.get_by_name(
                pkg_info.dependencies,
                product.dep_name,
            )
            if dep == None:
                fail("""\
Unable to resolve the package for the module aliases declared on product \
'{product}'. No dependency named '{dep_name}' was found in the root package \
manifest.\
""".format(product = product.product_name, dep_name = product.dep_name))
            aliases_by_identity.setdefault(dep.identity, {}).update(
                product.module_aliases,
            )
    return aliases_by_identity

def _non_root_target_mods_error(module_name, tag_groups):
    """Check that a non-root module did not declare target modification tags.

    Args:
        module_name: The name of the Bazel module as a `string`.
        tag_groups: A `list` of `struct` values with a `tag_class` `string`, a
            `verb` `string` and a `tags` `list`.

    Returns:
        A `string` describing the problem, or `None` if there is none.
    """
    declared = [tg.tag_class for tg in tag_groups if tg.tags]
    if not declared:
        return None
    return """\
Only the root module may declare `swift_deps` target modification tags, but \
module '{name}' declared: {declared}. Ask the maintainers of '{name}' to \
provide the setting a different way, or apply the modification from your root \
`MODULE.bazel`.\
""".format(
        declared = ", ".join(declared),
        name = module_name,
    )

def _build_file_conflict_error(package_name, build_file, target_mods):
    """Check that target modifications are not combined with a `build_file`.

    Args:
        package_name: The name of the Swift package as a `string`.
        build_file: The `build_file` override from the `configure_package` tag,
            or `None`.
        target_mods: The encoded target modifications as a `string`.

    Returns:
        A `string` describing the problem, or `None` if there is none.
    """
    if not build_file or not target_mods:
        return None
    return """\
Target modifications cannot be applied to package '{package}' because its \
`configure_package` tag supplies a complete `build_file` override. Remove the \
override or apply the modifications in that BUILD file.\
""".format(package = package_name)

# The `select()` branch value types that are declared as `string` values and
# converted to their Starlark type by this extension.
_BOOL_BRANCH = "bool"
_INT_BRANCH = "int"

_VERBS = bazel_target_mods.verbs

# Every target modification tag class, mapped to the `bazel_target_mods` verb
# that it declares. The tag class states the type of the value, so nothing is
# parsed or guessed. `branch_type` is set for the two `select()` tag classes
# whose branch values arrive as `string` values that must be converted.
_BAZEL_TARGET_MOD_TAG_SPECS = [
    struct(tag_class = "bazel_target_set_bool", verb = _VERBS.set, branch_type = None),
    struct(tag_class = "bazel_target_set_int", verb = _VERBS.set, branch_type = None),
    struct(tag_class = "bazel_target_set_string", verb = _VERBS.set, branch_type = None),
    struct(
        tag_class = "bazel_target_set_string_list",
        verb = _VERBS.set,
        branch_type = None,
    ),
    struct(
        tag_class = "bazel_target_set_string_dict",
        verb = _VERBS.set,
        branch_type = None,
    ),
    struct(
        tag_class = "bazel_target_set_select_bool_dict",
        verb = _VERBS.set_select,
        branch_type = _BOOL_BRANCH,
    ),
    struct(
        tag_class = "bazel_target_set_select_int_dict",
        verb = _VERBS.set_select,
        branch_type = _INT_BRANCH,
    ),
    struct(
        tag_class = "bazel_target_set_select_string_dict",
        verb = _VERBS.set_select,
        branch_type = None,
    ),
    struct(
        tag_class = "bazel_target_set_select_string_list_dict",
        verb = _VERBS.set_select,
        branch_type = None,
    ),
    struct(tag_class = "bazel_target_add", verb = _VERBS.add, branch_type = None),
    struct(
        tag_class = "bazel_target_add_select",
        verb = _VERBS.add_select,
        branch_type = None,
    ),
]

def _bool_branch_value(value):
    """Convert a `select()` branch value `string` to a `bool`.

    Args:
        value: The branch value as a `string`.

    Returns:
        A `bool` for `True` or `False`, spelled exactly as Starlark spells them.
        Otherwise, `None`.
    """
    if value == "True":
        return True
    if value == "False":
        return False
    return None

def _int_branch_value(value):
    """Convert a `select()` branch value `string` to an `int`.

    Args:
        value: The branch value as a `string`.

    Returns:
        An `int` for an all-digit value with an optional leading `-`. Otherwise,
        `None`.
    """
    digits = value[1:] if value.startswith("-") else value
    if digits == "" or not digits.isdigit():
        return None
    return int(value)

def _branch_values(tag_class, branch_type, tag):
    """Convert the `select()` branch values of a tag to their Starlark type.

    Args:
        tag_class: The name of the tag class as a `string`.
        branch_type: `bool` or `int` as a `string`.
        tag: The modification tag.

    Returns:
        A `struct` with a `values` `dict` mapping `select()` conditions to
        `bool` or `int` values and an `error` `string`. The `error` is `None`
        when every branch value was converted; otherwise, it describes the
        problem and `values` is `None`.
    """
    if branch_type == _BOOL_BRANCH:
        expected = "exactly `True` or `False`"
    else:
        expected = "an integer (digits with an optional leading `-`)"
    values = {}
    for (condition, value) in tag.values.items():
        if branch_type == _BOOL_BRANCH:
            converted = _bool_branch_value(value)
        else:
            converted = _int_branch_value(value)
        if converted == None:
            return struct(
                values = None,
                error = """\
The `{tag_class}` tag for '{target}' attribute '{attr}' has an invalid value \
for condition '{condition}': '{value}'. Values must be {expected}.\
""".format(
                    attr = tag.attr,
                    condition = condition,
                    expected = expected,
                    tag_class = tag_class,
                    target = tag.target,
                    value = value,
                ),
            )
        values[condition] = converted
    return struct(values = values, error = None)

def _converted_tag(tag_class, branch_type, tag):
    """Convert a `select()` tag's branch values to their Starlark type.

    Args:
        tag_class: The name of the tag class as a `string`.
        branch_type: `bool` or `int` as a `string`.
        tag: The modification tag.

    Returns:
        A `struct` with the tag's `attr`, `target` and converted `values`.
    """
    result = _branch_values(tag_class, branch_type, tag)
    if result.error != None:
        fail(result.error)
    return struct(attr = tag.attr, target = tag.target, values = result.values)

def _bazel_target_mod_tag_groups(mod, convert):
    """Collect the target modification tags declared by a Bazel module.

    Args:
        mod: A Bazel module as provided by `module_ctx.modules`.
        convert: A `bool` specifying whether the `select()` branch values that
            arrive as `string` values should be converted to their Starlark
            type. Conversion fails on a malformed value, so it is skipped for
            the modules that are rejected for declaring these tags at all.

    Returns:
        A `list` of `struct` values with a `tag_class` `string`, a `verb`
        `string` and a `tags` `list`.
    """
    tag_groups = []
    for spec in _BAZEL_TARGET_MOD_TAG_SPECS:
        tags = getattr(mod.tags, spec.tag_class)
        if convert and spec.branch_type != None:
            tags = [
                _converted_tag(spec.tag_class, spec.branch_type, tag)
                for tag in tags
            ]
        tag_groups.append(struct(
            tag_class = spec.tag_class,
            tags = tags,
            verb = spec.verb,
        ))
    return tag_groups

def _bazel_target_mods_by_repo(module_ctx):
    """Collect the buildozer-style target modifications from the root module.

    Args:
        module_ctx: An instance of `module_ctx`.

    Returns:
        A `dict` mapping a generated repository name to a `list` of
        modification `dict` values as returned by `bazel_target_mods.new`.
    """
    tag_groups = []
    for mod in module_ctx.modules:
        if not mod.is_root:
            error = _non_root_target_mods_error(
                mod.name,
                _bazel_target_mod_tag_groups(mod, convert = False),
            )
            if error != None:
                fail(error)
            continue
        tag_groups.extend(_bazel_target_mod_tag_groups(mod, convert = True))

    return bazel_target_mods.mods_by_repo(tag_groups)

def _declare_pkgs_from_package(
        module_ctx,
        from_package,
        config_pkgs,
        config_swift_package,
        target_mods_by_repo,
        matched_target_mod_repos,
        available_target_mod_repos):
    """Declare Swift packages from `Package.swift` and `Package.resolved`.

    Args:
        module_ctx: An instance of `module_ctx`.
        from_package: The data from the `from_package` tag.
        config_pkgs: The data from the `configure_package` tag.
        config_swift_package: The data from the `configure_swift_package` tag.
        target_mods_by_repo: A `dict` mapping a generated repository name to a
            `list` of target modification `dict` values.
        matched_target_mod_repos: A mutable `dict` recording the repository
            names from `target_mods_by_repo` that were found.
        available_target_mod_repos: A mutable `dict` recording every generated
            repository name that was found.
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
    workspace_root = str(pkg_swift.dirname)

    # The Bazel workspace root is the directory that the `local_swift_package`
    # repository rule resolves relative paths against (its
    # `repository_ctx.workspace_root`). It is derived from the `swift` label so
    # that it is correct even when `Package.swift` lives in a subdirectory
    # (e.g. `swift = "//:swift/Package.swift"`), in which case it differs from
    # `workspace_root` above.
    swift_repo_rel = paths.join(from_package.swift.package, from_package.swift.name)
    swift_suffix = "/" + swift_repo_rel
    abs_pkg_swift = str(pkg_swift)
    if abs_pkg_swift.endswith(swift_suffix):
        bazel_workspace_root = abs_pkg_swift[:-len(swift_suffix)]
    else:
        bazel_workspace_root = workspace_root

    root_cached_json_directory = None
    if from_package.cached_json_directory:
        root_cached_json_directory = paths.join(
            workspace_root,
            from_package.cached_json_directory,
        )

    pkg_info = pkginfos.get(
        module_ctx,
        directory = workspace_root,
        env = env,
        debug_path = str(debug_path),
        cached_json_directory = root_cached_json_directory,
        resolved_pkg_map = resolved_pkg_map,
        collect_src_info = False,
        registries_directory = registries_directory,
        replace_scm_with_registry = replace_scm_with_registry,
    )

    # Read SE-0339 module aliases from the root package manifest, keyed by
    # the identity of the providing package. The providing package renames
    # its module; that package and any package that directly depends on it
    # compile with `-module-alias` flags so their imports of the original
    # name resolve. Every repository receives the full map because a
    # repository's dependencies are only known once its manifest is parsed
    # inside the repository rule.
    module_aliases_by_id = _module_aliases_by_identity(pkg_info)
    dep_module_aliases_json = json.encode(module_aliases_by_id) if module_aliases_by_id else ""

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
                dep_cached_json_directory = None

                if from_package.cached_json_directory:
                    dep_cached_json_directory = paths.join(
                        dep.file_system.path,
                        from_package.cached_json_directory,
                    )
                dep_pkg_info = pkginfos.get(
                    module_ctx,
                    directory = dep.file_system.path,
                    debug_path = None,
                    cached_json_directory = dep_cached_json_directory,
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

    # Resolve the target modification repository names before declaring the
    # repositories. Unresolved dependencies from a stale `Package.resolved`
    # must still count as known repositories so that
    # `@swift_package//:resolve` remains available without first deleting the
    # modification tags.
    for dep in all_deps_by_id.values():
        dep_repo_name = bazel_repo_names.from_identity(dep.identity)
        available_target_mod_repos[dep_repo_name] = True
        if dep_repo_name in target_mods_by_repo:
            matched_target_mod_repos[dep_repo_name] = True

    # Declare the Bazel repositories.
    for dep in all_deps_by_id.values():
        # Declare a placeholder repository for unresolved dependencies.,
        # for example for a new packgage added to the `Package.swift`
        # which has not been resolved yet.
        # This allows the module extension to not fail abruptly in cases
        # where a new package dependency is added and a user runs
        # bazel run @swift_package//:resolve.
        if not dep.file_system and \
           (not dep.source_control or not dep.source_control.pin or not dep.source_control.pin.state) and \
           (not dep.registry or not dep.registry.pin):
            # buildifier: disable=print
            print("""
WARNING: {name} is unresolved and won't be available during the build, resolve \
the Swift package to make it available.\
""".format(name = dep.name))
            _declare_unresolved_pkg_from_dependency(dep)
            continue

        config_pkg = config_pkgs.get(dep.name)
        if config_pkg == None:
            config_pkg = config_pkgs.get(
                bazel_repo_names.from_identity(dep.identity),
            )
        _declare_pkg_from_dependency(
            dep,
            config_pkg,
            from_package,
            config_swift_package,
            from_package.cached_json_directory,
            config_pkg.target_deps if config_pkg else {},
            module_aliases_by_id.get(dep.identity, {}),
            dep_module_aliases_json,
            bazel_workspace_root,
            bazel_target_mods.encode(
                target_mods_by_repo.get(
                    bazel_repo_names.from_identity(dep.identity),
                    [],
                ),
            ),
        )

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

def _unresolved_swift_package_repo_impl(repository_ctx):
    repository_ctx.file("BUILD.bazel", "# NOTE: This is a placeholder for unresolved Swift packages.")

_unresolved_swift_package_repo = repository_rule(
    implementation = _unresolved_swift_package_repo_impl,
    attrs = {},
)

def _declare_unresolved_pkg_from_dependency(dep):
    name = bazel_repo_names.from_identity(dep.identity)
    _unresolved_swift_package_repo(name = name)

def _declare_pkg_from_dependency(
        dep,
        config_pkg,
        from_package,
        config_swift_package,
        cached_json_directory,
        target_deps,
        module_aliases,
        dep_module_aliases,
        bazel_workspace_root,
        target_mods):
    if cached_json_directory:
        cached_json_directory = paths.join(cached_json_directory, dep.name)
    name = bazel_repo_names.from_identity(dep.identity)
    build_file = None
    if config_pkg:
        build_file = config_pkg.build_file
    build_file_conflict = _build_file_conflict_error(
        dep.name,
        build_file,
        target_mods,
    )
    if build_file_conflict != None:
        fail(build_file_conflict)
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
            build_file = build_file,
            dependencies_index = None,
            env = from_package.env,
            env_inherit = from_package.env_inherit,
            cached_json_directory = cached_json_directory,
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
            target_deps = target_deps,
            module_aliases = module_aliases,
            dep_module_aliases = dep_module_aliases,
            bazel_target_mods = target_mods,
        )

    elif dep.file_system:
        # Store the local package path relative to the Bazel workspace root so
        # the lock file stays portable across machines and checkouts. The
        # `local_swift_package` rule re-absolutizes a relative path against its
        # `repository_ctx.workspace_root` at fetch time. Packages outside the
        # workspace root cannot be made portable and are left absolute.
        local_path = repository_utils.relativize_repo_path(
            dep.file_system.path,
            bazel_workspace_root,
        )
        if paths.is_absolute(local_path):
            # buildifier: disable=print
            print("""
WARNING: local Swift package '{identity}' resolves to '{path}', which is \
outside the Bazel workspace root. Its path will be stored as an absolute path \
in the lock file and will not be portable across machines.\
""".format(identity = dep.identity, path = local_path))
        local_swift_package(
            name = name,
            bazel_package_name = name,
            env = from_package.env,
            env_inherit = from_package.env_inherit,
            path = local_path,
            dependencies_index = None,
            build_file = build_file,
            cached_json_directory = cached_json_directory,
            target_deps = target_deps,
            module_aliases = module_aliases,
            dep_module_aliases = dep_module_aliases,
            bazel_target_mods = target_mods,
        )

    elif dep.registry:
        resolved = from_package.resolved if from_package else None
        replace_scm_with_registry = False
        if config_swift_package:
            replace_scm_with_registry = config_swift_package.replace_scm_with_registry

        registry_swift_package(
            name = name,
            bazel_package_name = name,
            build_file = build_file,
            env = from_package.env,
            env_inherit = from_package.env_inherit,
            id = dep.registry.pin.identity,
            registries = from_package.registries,
            replace_scm_with_registry = replace_scm_with_registry,
            resolved = resolved,
            target_deps = target_deps,
            version = dep.registry.pin.state.version,
            module_aliases = module_aliases,
            dep_module_aliases = dep_module_aliases,
            bazel_target_mods = target_mods,
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

    target_mods_by_repo = _bazel_target_mods_by_repo(module_ctx)
    matched_target_mod_repos = {}
    available_target_mod_repos = {}
    direct_dep_repo_names = []
    for mod in module_ctx.modules:
        for from_package in mod.tags.from_package:
            direct_dep_repo_names.extend(
                _declare_pkgs_from_package(
                    module_ctx,
                    from_package,
                    config_pkgs,
                    config_swift_package,
                    target_mods_by_repo,
                    matched_target_mod_repos,
                    available_target_mod_repos,
                ),
            )

    unknown_target_mod_repos = [
        repo_name
        for repo_name in target_mods_by_repo
        if repo_name not in matched_target_mod_repos
    ]
    if unknown_target_mod_repos:
        fail("""\
Target modifications were declared for unknown repositories: {unknown}. \
Available repositories are: {available}.\
""".format(
            available = ", ".join(sorted(available_target_mod_repos.keys())),
            unknown = ", ".join(sorted(unknown_target_mod_repos)),
        ))
    return module_ctx.extension_metadata(
        root_module_direct_deps = direct_dep_repo_names,
        root_module_direct_dev_deps = [],
    )

_from_package_tag = tag_class(
    attrs = dicts.add(
        swift_package_tool_attrs.swift_package_registry,
        {
            "cached_json_directory": attr.string(),
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
        "target_deps": attr.string_list_dict(
            doc = """\
Additional dependencies to add to generated targets for this package.

Keys are Swift package target names, such as `ExampleTarget`, which are mapped \
to generated implementation target names such as `ExampleTarget.rspm.__impl`. \
If the key already contains `.rspm`, it is matched as a generated target name \
unchanged. Values may be Bazel label strings or Swift package target names. \
Bare value strings and local label strings such as `OtherTarget` or \
`:OtherTarget` are mapped to generated target labels such as \
`:OtherTarget.rspm` when they match Swift package targets in the same \
generated BUILD package. Values that contain `.rspm`, external labels, \
cross-package labels, and local labels that do not match package targets are \
emitted unchanged.\
""",
        ),
    } | PATCH_ATTRS | TOOL_ATTRS,
    doc = "Used to add or override settings for a particular Swift package.",
)

_configure_swift_package_tag = tag_class(
    attrs = swift_package_tool_attrs.swift_package_tool_config,
    doc = "Used to configure the flags used when running the `swift package` binary.",
)

_BAZEL_TARGET_MOD_DOC_SUFFIX = """\

Only the root module may declare this tag.

There is no allowlist of attribute names. An attribute that the generated rule \
does not understand fails when Bazel loads the generated `BUILD.bazel` file, \
with Bazel's own error message. Use at your own risk.\
"""

_bazel_target_attr = attr.string(
    doc = """\
The name of the attribute to modify, such as `copts`. The `name` attribute may \
not be modified.\
""",
    mandatory = True,
)

_bazel_target_target_attr = attr.string(
    doc = """\
A label `string` naming a declaration in a generated repository, such as \
`@swiftpkg_foo//:Bar.rspm.__impl`. Every generated declaration lives in the \
root package of its repository, so the label must be of the form \
`@repo_name//:target_name`.\
""",
    mandatory = True,
)

_VERBATIM_VALUE_DOC = """\
The value is written into the generated `BUILD.bazel` file verbatim. Label \
values are not remapped, so a value such as `//:my_lib` resolves inside the \
generated repository, not your root module. Use `@@//:my_lib` to name a target \
in the main repository.\
"""

_VERBATIM_VALUES_DOC = """\
The values are written into the generated `BUILD.bazel` file verbatim. Label \
values are not remapped, so a value such as `//:my_lib` resolves inside the \
generated repository, not your root module. Use `@@//:my_lib` to name a target \
in the main repository.\
"""

_SELECT_KEYS_DOC = """\
Keys are absolute condition labels; a key that is relative to the main \
repository (e.g. `//:release_build`) is canonicalized (e.g. \
`@@//:release_build`) so that it still resolves from inside the generated \
repository. A key that names an apparent repository (a single `@`, e.g. \
`@some_repo//:setting`) is rejected, because it would be resolved against the \
generated repository's repository mapping; use a canonical label (e.g. \
`@@some_repo+//:setting`) instead.\
"""

_SET_SELECT_DEFAULT_DOC = """\
No `//conditions:default` branch is added for you.\
"""

_SET_SELECT_DOC = """\
Replace (or create) an attribute on a generated declaration with a `select()`.
""" + _BAZEL_TARGET_MOD_DOC_SUFFIX

def _bazel_target_set_tag_class(value_attr):
    """Create a tag class that replaces an attribute with a typed value.

    Args:
        value_attr: The `attr` for the `value` attribute.

    Returns:
        A `tag_class`.
    """
    return tag_class(
        attrs = {
            "attr": _bazel_target_attr,
            "target": _bazel_target_target_attr,
            "value": value_attr,
        },
        doc = """\
Replace (or create) an attribute on a generated declaration.
""" + _BAZEL_TARGET_MOD_DOC_SUFFIX,
    )

def _bazel_target_set_select_tag_class(values_attr):
    """Create a tag class that replaces an attribute with a `select()`.

    Args:
        values_attr: The `attr` for the `values` attribute.

    Returns:
        A `tag_class`.
    """
    return tag_class(
        attrs = {
            "attr": _bazel_target_attr,
            "target": _bazel_target_target_attr,
            "values": values_attr,
        },
        doc = _SET_SELECT_DOC,
    )

_bazel_target_set_bool_tag = _bazel_target_set_tag_class(
    attr.bool(
        doc = """\
The replacement value as a `bool`.\
""",
        mandatory = True,
    ),
)

_bazel_target_set_int_tag = _bazel_target_set_tag_class(
    attr.int(
        doc = """\
The replacement value as an `int`.\
""",
        mandatory = True,
    ),
)

_bazel_target_set_string_tag = _bazel_target_set_tag_class(
    attr.string(
        doc = """\
The replacement value as a `string`. An empty `string` is allowed.

""" + _VERBATIM_VALUE_DOC,
        mandatory = True,
    ),
)

_bazel_target_set_string_list_tag = _bazel_target_set_tag_class(
    attr.string_list(
        doc = """\
The replacement value as a `list` of `string` values. An empty `list` is \
allowed and clears the attribute.

""" + _VERBATIM_VALUES_DOC,
        mandatory = True,
    ),
)

_bazel_target_set_string_dict_tag = _bazel_target_set_tag_class(
    attr.string_dict(
        doc = """\
The replacement value as a `dict` of `string` keys to `string` values. An \
empty `dict` is allowed and clears the attribute.

""" + _VERBATIM_VALUES_DOC,
        mandatory = True,
    ),
)

_bazel_target_add_tag = tag_class(
    attrs = {
        "attr": _bazel_target_attr,
        "target": _bazel_target_target_attr,
        "values": attr.string_list(
            doc = """\
The values to append. At least one value is required. If the attribute is \
absent, it is created with these values.

""" + _VERBATIM_VALUES_DOC,
            mandatory = True,
        ),
    },
    doc = """\
Append values to a list attribute on a generated declaration.

The values are appended after the generated values, so options that follow \
last-option-wins semantics (e.g. `copts`) override the generated ones.
""" + _BAZEL_TARGET_MOD_DOC_SUFFIX,
)

_bazel_target_set_select_string_dict_tag = _bazel_target_set_select_tag_class(
    attr.string_dict(
        doc = """\
The `select()` branches, whose values are `string` values. \
""" + _SELECT_KEYS_DOC + " " + _SET_SELECT_DEFAULT_DOC + """
""" + _VERBATIM_VALUES_DOC,
        mandatory = True,
    ),
)

_bazel_target_set_select_string_list_dict_tag = _bazel_target_set_select_tag_class(
    attr.string_list_dict(
        doc = """\
The `select()` branches, whose values are `list` values of `string` values. \
""" + _SELECT_KEYS_DOC + " " + _SET_SELECT_DEFAULT_DOC + """
""" + _VERBATIM_VALUES_DOC,
        mandatory = True,
    ),
)

_bazel_target_set_select_bool_dict_tag = _bazel_target_set_select_tag_class(
    attr.string_dict(
        doc = """\
The `select()` branches, whose values are `string` values that are converted \
to a `bool`. Each value must be exactly `True` or `False`, spelled the way \
Starlark spells them; any other value fails when the module extension is \
evaluated. \
""" + _SELECT_KEYS_DOC + " " + _SET_SELECT_DEFAULT_DOC,
        mandatory = True,
    ),
)

_bazel_target_set_select_int_dict_tag = _bazel_target_set_select_tag_class(
    attr.string_dict(
        doc = """\
The `select()` branches, whose values are `string` values that are converted \
to an `int`. Each value must be digits with an optional leading `-`; any other \
value fails when the module extension is evaluated. \
""" + _SELECT_KEYS_DOC + " " + _SET_SELECT_DEFAULT_DOC,
        mandatory = True,
    ),
)

_bazel_target_add_select_tag = tag_class(
    attrs = {
        "attr": _bazel_target_attr,
        "target": _bazel_target_target_attr,
        "values": attr.string_list_dict(
            doc = """\
The `select()` branches, whose values are `list` values of `string` values. \
""" + _SELECT_KEYS_DOC + """ A `//conditions:default` branch with no values is \
added when one is not provided.

""" + _VERBATIM_VALUES_DOC,
            mandatory = True,
        ),
    },
    doc = """\
Append a `select()` to an attribute on a generated declaration.

The generated value is preserved: the attribute renders as \
`<generated> + select({...})`.
""" + _BAZEL_TARGET_MOD_DOC_SUFFIX,
)

swift_deps = module_extension(
    implementation = _swift_deps_impl,
    tag_classes = {
        "bazel_target_add": _bazel_target_add_tag,
        "bazel_target_add_select": _bazel_target_add_select_tag,
        "bazel_target_set_bool": _bazel_target_set_bool_tag,
        "bazel_target_set_int": _bazel_target_set_int_tag,
        "bazel_target_set_select_bool_dict": _bazel_target_set_select_bool_dict_tag,
        "bazel_target_set_select_int_dict": _bazel_target_set_select_int_dict_tag,
        "bazel_target_set_select_string_dict": _bazel_target_set_select_string_dict_tag,
        "bazel_target_set_select_string_list_dict": _bazel_target_set_select_string_list_dict_tag,
        "bazel_target_set_string": _bazel_target_set_string_tag,
        "bazel_target_set_string_dict": _bazel_target_set_string_dict_tag,
        "bazel_target_set_string_list": _bazel_target_set_string_list_tag,
        "configure_package": _configure_package_tag,
        "configure_swift_package": _configure_swift_package_tag,
        "from_package": _from_package_tag,
    },
)

swift_deps_test_utils = struct(
    branch_values = _branch_values,
    bazel_target_mod_tag_classes = [
        spec.tag_class
        for spec in _BAZEL_TARGET_MOD_TAG_SPECS
    ],
    bazel_target_mods_by_repo = _bazel_target_mods_by_repo,
    build_file_conflict_error = _build_file_conflict_error,
    non_root_target_mods_error = _non_root_target_mods_error,
)
