"""API for creating and loading Swift package information."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:sets.bzl", "sets")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
load(
    "//config_settings/spm/configuration:configurations.bzl",
    spm_configurations = "configurations",
)
load(
    "//config_settings/spm/platform:platforms.bzl",
    spm_platforms = "platforms",
)
load(":clang_files.bzl", "clang_files")
load(":deps_indexes.bzl", "deps_indexes")
load(":objc_files.bzl", "objc_files")
load(":pkginfo_dependencies.bzl", "pkginfo_dependencies")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":repository_files.bzl", "repository_files")
load(":repository_utils.bzl", "repository_utils")
load(":resource_files.bzl", "resource_files")
load(":swift_files.bzl", "swift_files")
load(":validations.bzl", "validations")

_DEFAULT_LOCALIZATION = "en"

def _get_dump_manifest(repository_ctx, env = {}, working_directory = ""):
    """Returns a dict representing the package dump for an SPM package.

    Args:
        repository_ctx: A `repository_ctx`.
        env: A `dict` of environment variables that will be included in the
             command execution.
        working_directory: A `string` specifying the directory for the SPM package.

    Returns:
        A `dict` representing an SPM package dump.
    """
    return repository_utils.parsed_json_from_spm_command(
        repository_ctx,
        ["swift", "package", "dump-package"],
        env = env,
        working_directory = working_directory,
        debug_json_path = "dump.json",
    )

def _get_desc_manifest(repository_ctx, env = {}, working_directory = ""):
    """Returns a dict representing the package description for an SPM package.

    Args:
        repository_ctx: A `repository_ctx`.
        env: A `dict` of environment variables that will be included in the
             command execution.
        working_directory: A `string` specifying the directory for the SPM package.

    Returns:
        A `dict` representing an SPM package description.
    """
    return repository_utils.parsed_json_from_spm_command(
        repository_ctx,
        ["swift", "package", "describe", "--type", "json"],
        env = env,
        working_directory = working_directory,
        debug_json_path = "desc.json",
    )

def _get(repository_ctx, directory, deps_index, env = {}):
    """Retrieves the package information for the Swift package defined at the \
    specified directory.

    Args:
        repository_ctx: A `repository_ctx`.
        directory: The path for the Swift package (`string`).
        deps_index: A `struct` as returned by `deps_indexes.new`.
        env: A `dict` of environment variables that will be included in the
             command execution.

    Returns:
        A `struct` representing the package information as returned by
        `pkginfos.new()`.
    """
    dump_manifest = _get_dump_manifest(
        repository_ctx,
        env = env,
        working_directory = directory,
    )
    desc_manifest = _get_desc_manifest(
        repository_ctx,
        env = env,
        working_directory = directory,
    )
    pkg_info = _new_from_parsed_json(
        repository_ctx = repository_ctx,
        dump_manifest = dump_manifest,
        desc_manifest = desc_manifest,
        deps_index = deps_index,
    )

    # Dump the merged pkg_info for debug purposes
    json_str = json.encode_indent(pkg_info, indent = "  ")
    repository_ctx.file("pkg_info.json", content = json_str, executable = False)

    return pkg_info

def _new_dependency_from_desc_json_map(dep_names_by_id, dep_map):
    identity = dep_map["identity"]
    name = dep_names_by_id.get(identity)
    if name == None:
        fail("Did not find dependency name for {identity}".format(
            identity = identity,
        ))

    return _new_dependency(
        identity = identity,
        name = name,
    )

def _new_product_from_desc_json_map(prd_map):
    does_not_exist = struct(exists = False)

    prd_type_map = prd_map["type"]
    executable = (
        prd_type_map.get("executable", default = does_not_exist) != does_not_exist
    )
    plugin = (
        prd_type_map.get("plugin", default = does_not_exist) != does_not_exist
    )
    library = None
    lib_list = prd_type_map.get("library")
    if lib_list != None and len(lib_list) > 0:
        library = _new_library_type(lib_list[0])
    prd_type = _new_product_type(
        executable = executable,
        library = library,
        plugin = plugin,
    )

    return _new_product(
        name = prd_map["name"],
        targets = prd_map["targets"],
        type = prd_type,
    )

def _new_target_dependency_condition_from_dump_json_map(dump_map):
    if dump_map == None:
        return None
    return _new_target_dependency_condition(
        platforms = dump_map.get("platformNames", default = []),
    )

def _new_target_dependency_from_dump_json_map(dump_map):
    by_name = None
    by_name_list = dump_map.get("byName")
    if by_name_list:
        by_name = _new_by_name_reference(
            name = by_name_list[0],
            condition = _new_target_dependency_condition_from_dump_json_map(
                by_name_list[1],
            ),
        )

    product = None
    product_list = dump_map.get("product")
    if product_list:
        product = _new_product_reference(
            product_name = product_list[0],
            # Per SPM code, a single name implies that the product,
            # package, and target all have the same name.
            dep_name = product_list[1] or product_list[0],
            condition = _new_target_dependency_condition_from_dump_json_map(
                product_list[3],
            ),
        )

    target = None
    target_list = dump_map.get("target")
    if target_list:
        target = _new_target_reference(
            target_name = target_list[0],
            condition = _new_target_dependency_condition_from_dump_json_map(
                target_list[1],
            ),
        )

    return _new_target_dependency(
        by_name = by_name,
        product = product,
        target = target,
    )

def _new_target_from_json_maps(
        repository_ctx,
        dump_map,
        desc_map,
        deps_index,
        pkg_path):
    repo_name = repository_ctx.attr.bazel_package_name
    if repo_name == "":
        repo_name = repository_ctx.name
    target_name = dump_map["name"]
    target_path = desc_map["path"]
    target_label = pkginfo_targets.bazel_label_from_parts(
        target_path = target_path,
        target_name = target_name,
        repo_name = repo_name,
    )
    dep_module = deps_indexes.get_module(deps_index, target_label)
    if dep_module == None:
        return None
    product_memberships = dep_module.product_memberships

    if len(product_memberships) == 0:
        return None
    dependencies = [
        _new_target_dependency_from_dump_json_map(d)
        for d in dump_map["dependencies"]
    ]
    clang_settings = _new_clang_settings_from_dump_json_list(
        dump_map["settings"],
    )
    cxx_settings = _new_cxx_settings_from_dump_json_list(
        dump_map["settings"],
    )
    swift_settings = _new_swift_settings_from_dump_json_list(
        dump_map["settings"],
    )
    linker_settings = _new_linker_settings_from_dump_json_list(
        dump_map["settings"],
    )

    # The description JSON should have a list with all of the resources with
    # their absolute paths.
    resources_set = sets.make([
        _new_resource_from_desc_map(r, pkg_path)
        for r in desc_map.get("resources", [])
    ])

    artifact_download_info = None
    url = dump_map.get("url")
    if url != None:
        artifact_download_info = _new_artifact_download_info(
            url = url,
            checksum = dump_map.get("checksum"),
        )
    c99name = desc_map["c99name"]
    module_type = desc_map["module_type"]
    sources = desc_map["sources"]
    source_paths = dump_map.get("sources")
    public_hdrs_path = dump_map.get("publicHeadersPath")
    exclude_paths = dump_map.get("exclude", default = [])

    swift_src_info = None
    clang_src_info = None
    objc_src_info = None
    if module_type == module_types.swift:
        swift_src_info = _new_swift_src_info_from_sources(
            repository_ctx,
            target_path,
            sources,
            exclude_paths = exclude_paths,
        )
        for p in swift_src_info.discovered_res_files:
            res = _new_resource_from_discovered_resource(p)
            sets.insert(resources_set, res)

    elif module_type == module_types.clang:
        other_hdr_srch_paths = []
        if clang_settings != None:
            other_hdr_srch_paths.extend(clang_settings.hdr_srch_paths)
        if cxx_settings != None:
            other_hdr_srch_paths.extend(cxx_settings.hdr_srch_paths)
        clang_src_info = _new_clang_src_info_from_sources(
            repository_ctx = repository_ctx,
            pkg_path = pkg_path,
            c99name = c99name,
            target_path = target_path,
            source_paths = source_paths,
            public_hdrs_path = public_hdrs_path,
            exclude_paths = exclude_paths,
            other_hdr_srch_paths = other_hdr_srch_paths,
        )
        if objc_files.has_objc_srcs(sources):
            objc_src_info = _new_objc_src_info_from_sources(
                repository_ctx = repository_ctx,
                pkg_path = pkg_path,
                sources = clang_src_info.explicit_srcs + clang_src_info.hdrs,
            )

    return _new_target(
        name = target_name,
        type = dump_map["type"],
        c99name = c99name,
        module_type = module_type,
        path = target_path,
        label = target_label,
        # List of sources provided by SPM
        sources = sources,
        # Exclude paths specified by the Swift package manifest author.
        exclude_paths = exclude_paths,
        # Source paths specified by the Swift package manifest author.
        source_paths = source_paths,
        dependencies = dependencies,
        clang_settings = clang_settings,
        cxx_settings = cxx_settings,
        swift_settings = swift_settings,
        linker_settings = linker_settings,
        public_hdrs_path = public_hdrs_path,
        artifact_download_info = artifact_download_info,
        product_memberships = product_memberships,
        resources = sets.to_list(resources_set),
        swift_src_info = swift_src_info,
        clang_src_info = clang_src_info,
        objc_src_info = objc_src_info,
    )

def _new_build_setting_condition_from_json(dump_map):
    if dump_map == None:
        return None
    return _new_build_setting_condition(
        platforms = dump_map.get("platformNames"),
        configuration = dump_map.get("config"),
    )

def _new_build_settings_from_json(dump_map):
    # Example build setting
    #   {
    #     "condition" : {
    #       "platformNames" : [
    #         "ios",
    #         "tvos"
    #       ]
    #     },
    #     "kind" : {
    #       "linkedFramework" : {
    #         "_0" : "UIKit"
    #       }
    #     },
    #     "tool" : "linker"
    #   }
    # Maps to build setting values:
    #   _new_build_setting(
    #       kind = "linkedFramework",
    #       values = ["UIKit"],
    #       condition = _new_build_setting_condition(
    #           platforms = ["ios", "tvos"],
    #       ),
    #   )
    condition = _new_build_setting_condition_from_json(
        dump_map.get("condition"),
    )
    kind_map = dump_map.get("kind")
    if kind_map == None:
        return []
    return [
        _new_build_setting(
            kind = build_setting_kind,
            # Some settings (e.g. unsafeFlags) are written as a list.
            values = lists.flatten(kind_type_values.values()),
            condition = condition,
        )
        for (build_setting_kind, kind_type_values) in kind_map.items()
    ]

def _new_clang_settings_from_dump_json_list(dump_list):
    build_settings = []
    for setting in dump_list:
        if setting["tool"] != "c":
            continue
        build_settings.extend(_new_build_settings_from_json(setting))
    return _new_clang_settings(build_settings)

def _new_cxx_settings_from_dump_json_list(dump_list):
    build_settings = []
    for setting in dump_list:
        if setting["tool"] != "cxx":
            continue
        build_settings.extend(_new_build_settings_from_json(setting))
    return _new_clang_settings(build_settings)

def _new_swift_settings_from_dump_json_list(dump_list):
    build_settings = []
    for setting in dump_list:
        if setting["tool"] != "swift":
            continue
        build_settings.extend(_new_build_settings_from_json(setting))
    return _new_swift_settings(build_settings)

def _new_linker_settings_from_dump_json_list(dump_list):
    build_settings = []
    for setting in dump_list:
        if setting["tool"] != "linker":
            continue
        build_settings.extend(_new_build_settings_from_json(setting))
    return _new_linker_settings(build_settings)

def _new_dependency_identity_to_name_map(dump_deps):
    result = {}
    for dep in dump_deps:
        identity_provider_list = (
            dep.get("sourceControl") or dep.get("fileSystem")
        )
        if not identity_provider_list:
            continue
        identity_provider = identity_provider_list[0]
        identity = identity_provider["identity"]

        # If a dependency has been given a name in the manifest, use it.
        # Otherwise, match on the identity.
        name = identity_provider.get(
            "nameForTargetDependencyResolutionOnly",
            default = identity,
        )
        result[identity] = name
    return result

def _new_from_parsed_json(repository_ctx, dump_manifest, desc_manifest, deps_index):
    """Returns the package information from the provided Swift package JSON \
    structures.

    Args:
        repository_ctx: A `repository_ctx`.
        dump_manifest: A `dict` representing the parsed JSON from `swift
            package dump-package`.
        desc_manifest: A `dict` representing the parsed JSON from `swift
            package describe`.
        deps_index: A `struct` as returned by `deps_indexes.new`.

    Returns:
        A `struct` representing the package information as returned by
        `pkginfos.new()`.
    """
    tools_version = dump_manifest["toolsVersion"]["_version"]
    platforms = [
        _new_platform(name = pl["platformName"], version = pl["version"])
        for pl in dump_manifest["platforms"]
    ]
    dep_names_by_id = _new_dependency_identity_to_name_map(
        dump_manifest["dependencies"],
    )
    dependencies = [
        _new_dependency_from_desc_json_map(dep_names_by_id, dep_map)
        for dep_map in desc_manifest["dependencies"]
    ]

    # Use the dump JSON to populate the products. This will avoid inclusion of
    # phantom products.
    products = [
        _new_product_from_desc_json_map(prd_map)
        for prd_map in dump_manifest["products"]
    ]

    desc_targets_by_name = {
        target_map["name"]: target_map
        for target_map in desc_manifest["targets"]
    }

    pkg_path = desc_manifest["path"]
    targets = lists.compact([
        _new_target_from_json_maps(
            repository_ctx = repository_ctx,
            dump_map = target_map,
            desc_map = desc_targets_by_name[target_map["name"]],
            deps_index = deps_index,
            pkg_path = pkg_path,
        )
        for target_map in dump_manifest["targets"]
    ])

    return _new(
        name = dump_manifest["name"],
        path = pkg_path,
        default_localization = desc_manifest.get(
            "default_localization",
            _DEFAULT_LOCALIZATION,
        ),
        tools_version = tools_version,
        platforms = platforms,
        dependencies = dependencies,
        products = products,
        targets = targets,
    )

# MARK: - Swift Package

def _new(
        name,
        path,
        default_localization = _DEFAULT_LOCALIZATION,
        tools_version = None,
        platforms = [],
        dependencies = [],
        products = [],
        targets = []):
    """Returns a `struct` representing information about a Swift package.

    Args:
        name: The name of the Swift package (`string`).
        path: The path to the Swift package (`string`).
        default_localization: Optional. The default localization region.
        tools_version: Optional. The semantic version for Swift from which the
            package was created (`string`).
        platforms: A `list` of platform structs as created by
            `pkginfos.new_platform()`.
        dependencies: A `list` of external depdency structs as created by
            `pkginfos.new_dependency()`.
        products: A `list` of product structs as created by
            `pkginfos.new_product()`.
        targets: A `list` of target structs as created by
            `pkginfos.new_target()`.

    Returns:
        A `struct` representing information about a Swift package.
    """
    return struct(
        name = name,
        path = path,
        default_localization = default_localization,
        tools_version = tools_version,
        platforms = platforms,
        dependencies = dependencies,
        products = products,
        targets = targets,
    )

# MARK: - Platform

def _new_platform(name, version):
    """Creates a `struct` with information about a platform.

    Args:
        name: The name of the platform (`string`).
        version: The minimum version for the platorm (`string`).

    Returns:
        A `struct` representing a Swift package platform.
    """
    return struct(
        name = name,
        version = version,
    )

# MARK: - External Dependency

def _new_dependency(identity, name):
    """Creates a `struct` representing an external dependency for a Swift \
    package.

    Args:
        identity: The identifier for the external depdendency (`string`).
        name: The name used for package reference resolution (`string`).

    Returns:
        A `struct` representing an external dependency.
    """
    return struct(
        identity = identity,
        name = pkginfo_dependencies.normalize_name(name),
    )

def _new_dependency_requirement(ranges = None):
    """Creates a `struct` representing the requirements for an external \
    dependency.

    Args:
        ranges: Optional. A `list` of version range `struct` values as returned
            by `pkginfos.new_version_range()`.

    Returns:
        A `struct` representing the requirements for an external dependency.
    """
    if ranges == None:
        fail("""\
A depdendency requirement must have one of the following: `ranges`.\
""")
    return struct(
        ranges = ranges,
    )

def _new_version_range(lower, upper):
    """Creates a `struct` representing a version range.

    Args:
        lower: The minimum semantic version (`string`).
        upper: The non-inclusive maximum semantic version (`string`).

    Returns:
        A `struct` representing a version range.
    """
    return struct(
        lower = lower,
        upper = upper,
    )

# MARK: - Product

def _new_product_type(executable = False, library = None, plugin = False):
    """Creates a product type.

    Args:
        executable: A `bool` specifying whether the product is an executable.
        library: A `struct` as returned by `pkginfos.new_library_type`.
        plugin: A `bool` specifying whether the product is a plugin.

    Returns:
        A `struct` representing a product type.
    """
    is_executable = executable
    is_library = (library != None)
    is_plugin = plugin
    type_bools = [is_executable, is_library, is_plugin]
    true_cnt = 0
    for bt in type_bools:
        if bt:
            true_cnt = true_cnt + 1
    if true_cnt == 0:
        fail("A product type must be one of the following: executable, library, plugin.")
    elif true_cnt > 1:
        fail("Multiple args provided to `pkginfos.new_product_type`.")

    return struct(
        executable = executable,
        library = library,
        # Type boolean values
        is_executable = is_executable,
        is_library = is_library,
        is_plugin = is_plugin,
    )

def _new_library_type(kind):
    """Creates a library type as expected by `pkginfos.new_product_type`.

    Args:
        kind: The kind of library. Must be one of `library_type_kinds`.

    Returns:
        A `struct` representing a library type.
    """
    validations.in_list(
        library_type_kinds.all_values,
        kind,
        "Invalid library type kind. kind:",
    )
    return struct(
        kind = kind,
    )

def _new_product(name, type, targets):
    """Creates a product.

    Args:
        name: The name of the product as a `string`.
        type: A `struct` as returned by `pkginfos.new_product_type`.
        targets: A `list` of target names (`string`).

    Returns:
        A `struct` representing a product.
    """
    return struct(
        name = name,
        type = type,
        targets = targets,
    )

# MARK: - Dependency References

def _new_target_dependency_condition(platforms = []):
    """Create a target dependency condition.

    Args:
        platforms: Optional. A `list` of platform names as `string` values.

    Returns:
        A `struct` representing a target dependency condition.
    """
    if len(platforms) == 0:
        return None
    return struct(
        platforms = platforms,
    )

def _new_product_reference(product_name, dep_name, condition = None):
    """Creates a product reference.

    Args:
        product_name: The name of the product (`string`).
        dep_name: The name of the external dependency (`string`).
        condition: Optional. A `struct` as returned by
            `pkginfos.new_target_dependency_condition`.

    Returns:
        A `struct` representing a product reference.
    """
    return struct(
        product_name = product_name,
        dep_name = dep_name,
        condition = condition,
    )

def _new_by_name_reference(name, condition = None):
    """Creates a by-name reference.

    Args:
        name: The name of a target or product (`string`).
        condition: Optional. A `struct` as returned by
            `pkginfos.new_target_dependency_condition`.

    Returns:
        A `struct` representing a by-name reference.
    """
    return struct(
        name = name,
        condition = condition,
    )

def _new_target_reference(target_name, condition = None):
    """Creates a target reference.

    Args:
        target_name: The name of a target (`string`).
        condition: Optional. A `struct` as returned by
            `pkginfos.new_target_dependency_condition`.

    Returns:
        A `struct` representing a target reference.
    """
    return struct(
        target_name = target_name,
        condition = condition,
    )

def _new_target_dependency(by_name = None, product = None, target = None):
    """Creates a target dependency.

    Args:
        by_name: A `struct` as returned by
            `pkginfos.new_by_name_reference()`.
        product: A `struct` as returned by
            `pkginfos.new_product_reference()`.
        target: A `struct` as returned by
            `pkginfos.new_target_reference()`.

    Returns:
        A `struct` representing a target dependency.
    """
    if by_name == None and product == None and target == None:
        fail("""\
A target dependency must have one of the following: `by_name`, `product`, `target`.\
""")
    return struct(
        by_name = by_name,
        product = product,
        target = target,
    )

# MARK: - Swift Source Info

def _new_swift_src_info_from_sources(
        repository_ctx,
        target_path,
        sources,
        exclude_paths = []):
    # Check for any @objc directives in the source files
    has_objc_directive = False
    for src in sources:
        path = paths.join(target_path, src)
        contents = repository_ctx.read(path)
        if swift_files.has_objc_directive(contents):
            has_objc_directive = True
        if has_objc_directive:
            break

    # Find any auto-discoverable resources under the target
    all_target_files = repository_files.list_files_under(
        repository_ctx,
        target_path,
        exclude_paths = exclude_paths,
    )

    # Identify the directories
    directories = repository_files.list_directories_under(
        repository_ctx,
        target_path,
        exclude_paths = exclude_paths,
    )
    dirs_set = sets.make(directories)

    # The paths should be relative to the target not the root of the workspace.
    # Do not include directories in the output.
    discovered_res_files = [
        f
        for f in all_target_files
        if not sets.contains(dirs_set, f) and
           resource_files.is_auto_discovered_resource(f)
    ]

    return _new_swift_src_info(
        has_objc_directive = has_objc_directive,
        discovered_res_files = discovered_res_files,
    )

def _new_swift_src_info(
        has_objc_directive = False,
        discovered_res_files = []):
    return struct(
        has_objc_directive = has_objc_directive,
        discovered_res_files = discovered_res_files,
    )

# MARK: - Clang Source Info

def _new_clang_src_info_from_sources(
        repository_ctx,
        pkg_path,
        c99name,
        target_path,
        source_paths,
        public_hdrs_path,
        exclude_paths,
        other_hdr_srch_paths = []):
    # Absolute path to the target. This is typically used for filesystem
    # actions, not for values added to the cc_library or objc_library.
    abs_target_path = paths.normalize(
        paths.join(pkg_path, target_path),
    )

    public_includes = []
    if public_hdrs_path != None:
        public_includes.append(
            paths.normalize(paths.join(abs_target_path, public_hdrs_path)),
        )

    # If the Swift package manifest has explicit source paths, respect them.
    # (Be sure to include any explicitly specified include directories.)
    # Otherwise, use all of the source files under the target path.
    if source_paths != None:
        src_paths = [
            paths.normalize(paths.join(abs_target_path, sp))
            for sp in source_paths
        ]

        # The public includes are already relative to the abs_target_path.
        src_paths.extend([
            paths.normalize(paths.join(pkg_path, pi))
            for pi in public_includes
        ])
        src_paths = sets.to_list(sets.make(src_paths))
    else:
        src_paths = [abs_target_path]

    def _format_exclude_path(ep):
        abs_path = paths.normalize(paths.join(abs_target_path, ep))
        if repository_files.is_directory(repository_ctx, abs_path):
            # The trailing slash tells repository_files.list_files_under() to
            # exclude any files that start with the path.
            abs_path += "/"
        return abs_path

    abs_exclude_paths = [
        _format_exclude_path(ep)
        for ep in exclude_paths
    ]

    # Get a list of all of the source files
    all_srcs = []
    for sp in src_paths:
        all_srcs.extend(repository_files.list_files_under(
            repository_ctx,
            sp,
            exclude_paths = abs_exclude_paths,
        ))

    # Organize the source files
    # Be sure that the all_srcs and the public_includes that are passed to
    # `collect_files` are all absolute paths.  The relative_to option will
    # ensure that the output values are relative to the package path.
    organized_files = clang_files.collect_files(
        repository_ctx,
        all_srcs,
        c99name,
        public_includes = [
            paths.normalize(paths.join(pkg_path, pi))
            for pi in public_includes
        ],
        relative_to = pkg_path,
    )

    # The `cc_library` rule compiles each source file (.c, .cc) separately only providing the
    # headers. There are some clang modules (e.g.,
    # https://github.com/soto-project/soto-core/tree/main/Sources/CSotoExpat) that include
    # non-header files (e.g. `#include "xmltok_impl.c"`). The ensure that all of the files are
    # present for compilation, we add any non-header source files to the `textual_hdrs`.
    # Related to GH252.
    textual_hdrs = organized_files.textual_hdrs
    hdrs = []
    srcs = []
    explicit_srcs = []
    public_includes = organized_files.public_includes
    private_includes = organized_files.private_includes
    if len(organized_files.srcs) > 0:
        explicit_srcs.extend(organized_files.srcs)
        srcs.extend(organized_files.srcs)
    if len(organized_files.hdrs) > 0:
        hdrs.extend(organized_files.hdrs)

    # Look for header files that are not under the target path
    extra_hdr_dirs = []
    extra_hdr_dirs.extend(lists.flatten([
        [paths.join(target_path, path) for path in bs.values]
        for bs in other_hdr_srch_paths
    ]))
    if target_path != ".":
        for pi in private_includes:
            normalized_pi = paths.normalize(pi)
            if clang_files.is_under_path(normalized_pi, target_path):
                continue
            extra_hdr_dirs.append(normalized_pi)

    for ehd in extra_hdr_dirs:
        abs_ehd = paths.normalize(paths.join(pkg_path, ehd))
        if not repository_files.path_exists(repository_ctx, abs_ehd):
            # Do not fail if the path does not exist.
            continue
        hdr_paths = repository_files.list_files_under(repository_ctx, abs_ehd)
        hdr_paths = [
            clang_files.relativize(hp, pkg_path)
            for hp in hdr_paths
            if clang_files.is_hdr(hp)
        ]
        srcs.extend(hdr_paths)

    # Remove any hdrs from the srcs
    srcs_set = sets.make(srcs)
    explicit_srcs_set = sets.make(explicit_srcs)
    hdrs_set = sets.make(hdrs)
    srcs_set = sets.difference(srcs_set, hdrs_set)
    hdrs = sets.to_list(hdrs_set)
    srcs = sets.to_list(srcs_set)
    explicit_srcs = sets.to_list(explicit_srcs_set)

    return _new_clang_src_info(
        srcs = srcs,
        explicit_srcs = explicit_srcs,
        hdrs = hdrs,
        textual_hdrs = textual_hdrs,
        public_includes = public_includes,
        private_includes = private_includes,
        modulemap_path = organized_files.modulemap,
    )

def _new_clang_src_info(
        srcs = [],
        explicit_srcs = [],
        hdrs = [],
        textual_hdrs = [],
        public_includes = [],
        private_includes = [],
        modulemap_path = None):
    return struct(
        srcs = srcs,
        explicit_srcs = explicit_srcs,
        hdrs = hdrs,
        textual_hdrs = textual_hdrs,
        public_includes = public_includes,
        private_includes = private_includes,
        modulemap_path = modulemap_path,
    )

# MARK: - Objc Source Info

def _new_objc_src_info_from_sources(repository_ctx, pkg_path, sources):
    srcs = lists.map(sources, lambda s: paths.join(pkg_path, s))
    src_info = objc_files.collect_src_info(
        repository_ctx = repository_ctx,
        root_path = pkg_path,
        srcs = srcs,
    )

    imports_xctest = False
    xctest_srcs = src_info.all_imports.get("XCTest", [])
    if xctest_srcs != []:
        imports_xctest = True

    return _new_objc_src_info(
        builtin_frameworks = src_info.frameworks,
        imports_xctest = imports_xctest,
    )

def _new_objc_src_info(builtin_frameworks = [], imports_xctest = False):
    return struct(
        builtin_frameworks = builtin_frameworks,
        imports_xctest = imports_xctest,
    )

# MARK: - Target

def _new_target(
        name,
        type,
        c99name,
        module_type,
        path,
        sources,
        dependencies,
        label = None,
        repo_name = None,
        exclude_paths = [],
        source_paths = None,
        clang_settings = None,
        cxx_settings = None,
        swift_settings = None,
        linker_settings = None,
        public_hdrs_path = None,
        artifact_download_info = None,
        product_memberships = [],
        resources = [],
        swift_src_info = None,
        clang_src_info = None,
        objc_src_info = None):
    """Creates a target.

    Args:
        name: The name of the target (`string`).
        type: The type of target (`string`).
        c99name: The C name for the target (`string`).
        module_type: The module type (`string`).
        path: The path to the Swift package (`string`).
        sources: A `list` of the source files (`string`) in the module relative
            to the `path`.
        dependencies: A `list` of target dependency values as returned by
            `pkginfos.new_target_dependency()`.
        label: Optional. The Bazel label `struct` for the target as returned by
            `bazel_labels.new`. Either this or `repo_name` needs to be
            specified.
        repo_name: Optional. The repository name as a `string`. Either this or
            `label` need to be speicified.
        exclude_paths: Optional. A `list` of paths that should be excluded as
            specified by the Swift package manifest author.
        source_paths: Optional. A `list` of paths (`string` values) specified by
            the Swift package manfiest author.
        clang_settings: Optional. A `struct` as returned by `pkginfos.new_clang_settings`.
        cxx_settings: Optional. A `struct` as returned by `pkginfos.new_clang_settings`.
        swift_settings: Optional. A `struct` as returned by `pkginfos.new_swift_settings`.
        linker_settings: Optional. A `struct` as returned by `pkginfos.new_linker_settings`.
        public_hdrs_path: Optional. A `string`.
        artifact_download_info: Optional. A `struct` as returned by
            `pkginfos.new_artifact_download_info`.
        product_memberships: Optional. A `list` of product names that this
            target is referenced by.
        resources: Optional. A `list` of resource `struct` values as returned
            by `pkginfos.new_resource`.
        swift_src_info: Optional. A `struct` as returned by
            `pkginfos.new_swift_src_info`. If the target is a Swift target, this
            will not be `None`.
        clang_src_info: Optional. A `struct` as returned by
            `pkginfos.new_clang_src_info`. If the target is a clang target, this
            will not be `None`.
        objc_src_info: Optional. A `struct` as returned by
            `pkginfos.new_objc_src_info`. If the target is an Objc target, this
            will not be `None`.

    Returns:
        A `struct` representing a target in a Swift package.
    """
    validations.in_list(
        target_types.all_values,
        type,
        "Unrecognized target type. type:",
    )
    validations.in_list(
        module_types.all_values,
        module_type,
        "Unrecognized module type. type:",
    )

    # NOTE: We are explicitly not normalizing the exclude_paths. The inclusion
    # of a trailing slash can be critical when the exclude logic is applied.
    normalized_src_paths = None
    if source_paths != None:
        normalized_src_paths = [
            sp[:-1] if sp.endswith("/") else sp
            for sp in source_paths
        ]
    if label == None and repo_name == None:
        fail("Need to specify `label` or `repo_name`.")
    if label == None:
        label = pkginfo_targets.bazel_label_from_parts(
            target_path = path,
            target_name = name,
            repo_name = repo_name,
        )
    return struct(
        name = name,
        type = type,
        c99name = c99name,
        module_type = module_type,
        path = path,
        sources = sources,
        dependencies = dependencies,
        label = label,
        exclude_paths = exclude_paths,
        source_paths = normalized_src_paths,
        clang_settings = clang_settings,
        cxx_settings = cxx_settings,
        swift_settings = swift_settings,
        linker_settings = linker_settings,
        public_hdrs_path = public_hdrs_path,
        artifact_download_info = artifact_download_info,
        product_memberships = product_memberships,
        resources = resources,
        swift_src_info = swift_src_info,
        clang_src_info = clang_src_info,
        objc_src_info = objc_src_info,
    )

# MARK: - Build Settings

def _new_build_setting_condition(platforms = [], configuration = None):
    """Create a build setting condition.

    Args:
        platforms: Optional. A `list` of platform names as `string` values.
        configuration: Optional. The name of an SPM configuration as a `string`
            value.

    Returns:
        A `struct` representing build setting condition.
    """
    if platforms == [] and configuration == None:
        return None

    platforms = spm_platforms.supported(platforms)
    if configuration != None:
        validations.in_list(
            spm_configurations.all_values,
            configuration,
            "Unrecognized configuration. configuration:",
        )

    return struct(
        platforms = platforms,
        configuration = configuration,
    )

def _new_build_setting(kind, values, condition = None):
    """Create a build setting data struct.

    Args:
        kind: The name of the build setting as a `string`.
        values: The value for the build setting as a `list`.
        condition: Optional. A `struct` as returned by
            `pkginfos.new_build_setting_condition`.

    Returns:
        A `struct` representing a build setting.
    """
    return struct(
        kind = kind,
        values = values,
        condition = condition,
    )

def _new_clang_settings(build_settings):
    """Create a clang/cxx setting data struct.

    Args:
        build_settings: A `list` of `struct` values as returned by
            `pkginfos.new_build_setting`.

    Returns:
        A `struct` representing the clang settings.
    """
    defines = []
    hdr_srch_paths = []
    unsafe_flags = []
    for bs in build_settings:
        if bs.kind == build_setting_kinds.define:
            defines.append(bs)
        elif bs.kind == build_setting_kinds.header_search_path:
            hdr_srch_paths.append(bs)
        elif bs.kind == build_setting_kinds.unsafe_flags:
            unsafe_flags.append(bs)
        else:
            # We do not recognize the setting.
            pass
    if len(defines) == 0 and \
       len(hdr_srch_paths) == 0 and \
       len(unsafe_flags) == 0:
        return None
    return struct(
        defines = defines,
        hdr_srch_paths = hdr_srch_paths,
        unsafe_flags = unsafe_flags,
    )

def _new_swift_settings(build_settings):
    """Create a Swift setting data struct.

    Args:
        build_settings: A `list` of `struct` values as returned by
            `pkginfos.new_build_setting`.

    Returns:
        A `struct` representing the Swift settings.
    """
    defines = []
    unsafe_flags = []
    experimental_features = []
    for bs in build_settings:
        if bs.kind == build_setting_kinds.define:
            defines.append(bs)
        elif bs.kind == build_setting_kinds.unsafe_flags:
            unsafe_flags.append(bs)
        elif bs.kind == build_setting_kinds.experimental_features:
            experimental_features.append(bs)
        else:
            # We do not recognize the setting.
            pass
    if len(defines) == 0 and \
       len(unsafe_flags) == 0 and \
       len(experimental_features) == 0:
        return None
    return struct(
        defines = defines,
        unsafe_flags = unsafe_flags,
        experimental_features = experimental_features,
    )

def _new_linker_settings(build_settings):
    """Create a linker setting data struct.

    Args:
        build_settings: A `list` of `struct` values as returned by
            `pkginfos.new_build_setting`.

    Returns:
        A `struct` representing the linker settings.
    """
    linked_libraries = []
    linked_frameworks = []
    for bs in build_settings:
        if bs.kind == build_setting_kinds.linked_library:
            linked_libraries.append(bs)
        elif bs.kind == build_setting_kinds.linked_framework:
            linked_frameworks.append(bs)
        else:
            # We do not recognize the setting.
            pass
    if len(linked_libraries) == 0 and len(linked_frameworks) == 0:
        return None
    return struct(
        linked_libraries = linked_libraries,
        linked_frameworks = linked_frameworks,
    )

# MARK: - Binary Target

def _new_artifact_download_info(url, checksum):
    return struct(
        url = url,
        checksum = checksum,
    )

# MARK: - Resources

def _new_resource(path, rule):
    """Create a resource.

    Args:
        path: The relative path to the resource as a `string`.
        rule: A `struct` as returned by `pkginfos.new_resource_rule`.

    Returns:
        A `struct` representing a target resource.
    """
    return struct(
        path = path,
        rule = rule,
    )

def _new_resource_rule(process = None, copy = None, embed_in_code = None):
    """Create a resource rule.

    Args:
        process: Optional. A `struct` as returned by `pkginfos.new_resource_rule_process`.
        copy: Optional. A `bool` specifying whether it is a copy action.
        embed_in_code: Optional. A `bool` specifying whether it is an embedInCode.

    Returns:
        A `struct` representing a resource rule.
    """
    arg_cnt = 0
    if process != None:
        arg_cnt += 1
    if copy != None:
        arg_cnt += 1
    if embed_in_code != None:
        arg_cnt += 1
    if arg_cnt == 0:
        fail("Must specify one of the following: process, copy, or embed_in_code.")
    if arg_cnt > 1:
        fail("Only one can be specified: process, copy, or embed_in_code.")
    return struct(
        process = process,
        copy = copy,
        embed_in_code = embed_in_code,
    )

def _new_resource_rule_process(localization = None):
    """Create a resource rule process.

    Args:
        localization: Optional. The localization as a `string`.

    Returns:
        A `struct` representing a resource rule process.
    """
    return struct(
        localization = localization,
    )

def _new_resource_from_desc_map(desc_map, pkg_path):
    path = desc_map["path"]
    if paths.is_absolute(path):
        path = paths.relativize(path, pkg_path)
    return _new_resource(
        path = path,
        rule = _new_resource_rule_from_desc_json_map(desc_map["rule"]),
    )

def _new_resource_rule_from_desc_json_map(desc_map):
    process = _new_resource_rule_process_from_desc_json_map(
        desc_map.get("process"),
    )
    copy = True if desc_map.get("copy") != None else None
    embed_in_code = True if desc_map.get("embedInCode") != None else None
    return _new_resource_rule(
        process = process,
        copy = copy,
        embed_in_code = embed_in_code,
    )

def _new_resource_rule_process_from_desc_json_map(desc_map):
    if desc_map == None:
        return None
    return _new_resource_rule_process(
        localization = desc_map.get("localization"),
    )

def _new_resource_from_discovered_resource(path):
    # Building the resource to look like the structures defined in
    # https://github.com/apple/swift-package-manager/blob/main/Sources/PackageLoading/TargetSourcesBuilder.swift#L634-L677
    return _new_resource(
        path = path,
        rule = _new_resource_rule(
            process = _new_resource_rule_process(),
        ),
    )

# MARK: - Constants

target_types = struct(
    binary = "binary",
    executable = "executable",
    library = "library",
    macro = "macro",
    plugin = "plugin",
    regular = "regular",
    system = "system",
    test = "test",
    all_values = [
        "binary",
        "executable",
        "library",
        "macro",
        "plugin",
        "regular",
        "system",
        "test",
    ],
)

module_types = struct(
    binary = "BinaryTarget",
    clang = "ClangTarget",
    plugin = "PluginTarget",
    swift = "SwiftTarget",
    system_library = "SystemLibraryTarget",
    all_values = [
        "BinaryTarget",
        "ClangTarget",
        "PluginTarget",
        "SwiftTarget",
        "SystemLibraryTarget",
    ],
)

library_type_kinds = struct(
    automatic = "automatic",
    dynamic = "dynamic",
    static = "static",
    all_values = ["automatic", "dynamic", "static"],
)

build_setting_kinds = struct(
    define = "define",
    header_search_path = "headerSearchPath",
    linked_framework = "linkedFramework",
    linked_library = "linkedLibrary",
    unsafe_flags = "unsafeFlags",
    experimental_features = "enableExperimentalFeature",
)

# MARK: - API Definition

pkginfos = struct(
    get = _get,
    new = _new,
    new_artifact_download_info = _new_artifact_download_info,
    new_build_setting = _new_build_setting,
    new_build_setting_condition = _new_build_setting_condition,
    new_by_name_reference = _new_by_name_reference,
    new_clang_settings = _new_clang_settings,
    new_clang_src_info = _new_clang_src_info,
    new_dependency = _new_dependency,
    new_dependency_requirement = _new_dependency_requirement,
    new_from_parsed_json = _new_from_parsed_json,
    new_library_type = _new_library_type,
    new_linker_settings = _new_linker_settings,
    new_objc_src_info = _new_objc_src_info,
    new_platform = _new_platform,
    new_product = _new_product,
    new_product_reference = _new_product_reference,
    new_product_type = _new_product_type,
    new_resource = _new_resource,
    new_resource_rule = _new_resource_rule,
    new_resource_rule_process = _new_resource_rule_process,
    new_swift_settings = _new_swift_settings,
    new_swift_src_info = _new_swift_src_info,
    new_target = _new_target,
    new_target_dependency = _new_target_dependency,
    new_target_dependency_condition = _new_target_dependency_condition,
    new_target_dependency_from_dump_json_map = _new_target_dependency_from_dump_json_map,
    new_target_reference = _new_target_reference,
    new_version_range = _new_version_range,
)
