"""API for creating and loading Swift package information."""

load(
    "//config_settings/spm/configuration:configurations.bzl",
    spm_configurations = "configurations",
)
load(
    "//config_settings/spm/platform:platforms.bzl",
    spm_platforms = "platforms",
)
load(":pkginfo_dependencies.bzl", "pkginfo_dependencies")
load(":repository_utils.bzl", "repository_utils")
load(":validations.bzl", "validations")

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

def _get(repository_ctx, directory, env = {}):
    """Retrieves the package information for the Swift package defined at the \
    specified directory.

    Args:
        repository_ctx: A `repository_ctx`.
        directory: The path for the Swift package (`string`).
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
    return _new_from_parsed_json(
        dump_manifest = dump_manifest,
        desc_manifest = desc_manifest,
    )

def _new_dependency_requirement_from_desc_json_map(req_map):
    ranges = req_map.get("range")
    if ranges != None:
        return _new_dependency_requirement(
            ranges = [
                _new_version_range(
                    lower = rangeMap["lower_bound"],
                    upper = rangeMap["upper_bound"],
                )
                for rangeMap in ranges
            ],
        )
    return None

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
        type = dep_map["type"],
        url = dep_map["url"],
        requirement = _new_dependency_requirement_from_desc_json_map(dep_map["requirement"]),
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

def _new_target_dependency_from_dump_json_map(dep_map):
    by_name_list = dep_map.get("byName")
    by_name = _new_by_name_reference(by_name_list[0]) if by_name_list else None

    product = None
    product_list = dep_map.get("product")
    if product_list:
        product = _new_product_reference(
            product_name = product_list[0],
            dep_name = product_list[1],
        )

    target_list = dep_map.get("target")
    target = _new_target_reference(target_list[0]) if target_list else None

    return _new_target_dependency(
        by_name = by_name,
        product = product,
        target = target,
    )

def _new_target_from_json_maps(dump_map, desc_map):
    dependencies = [
        _new_target_dependency_from_dump_json_map(d)
        for d in dump_map["dependencies"]
    ]
    clang_settings = _new_clang_settings_from_dump_json_list(
        dump_map["settings"],
    )
    swift_settings = _new_swift_settings_from_dump_json_list(
        dump_map["settings"],
    )
    linker_settings = _new_linker_settings_from_dump_json_list(
        dump_map["settings"],
    )
    artifact_download_info = None
    url = dump_map.get("url")
    if url != None:
        artifact_download_info = _new_artifact_download_info(
            url = url,
            checksum = dump_map.get("checksum"),
        )
    return _new_target(
        name = dump_map["name"],
        type = dump_map["type"],
        c99name = desc_map["c99name"],
        module_type = desc_map["module_type"],
        path = desc_map["path"],
        # List of sources provided by SPM
        sources = desc_map["sources"],
        # Exclude paths specified by the Swift package manifest author.
        exclude_paths = dump_map.get("exclude", default = []),
        # Source paths specified by the Swift package manifest author.
        source_paths = dump_map.get("sources"),
        dependencies = dependencies,
        clang_settings = clang_settings,
        swift_settings = swift_settings,
        linker_settings = linker_settings,
        public_hdrs_path = dump_map.get("publicHeadersPath"),
        artifact_download_info = artifact_download_info,
        product_memberships = desc_map.get("product_memberships", default = []),
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
            values = kind_type_values.values(),
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
        src_ctrl_list = dep.get("sourceControl")
        if src_ctrl_list == None or len(src_ctrl_list) == 0:
            continue
        src_ctrl = src_ctrl_list[0]
        identity = src_ctrl["identity"]

        # If a dependency has been given a name in the manifest, use it.
        # Otherwise, match on the identity.
        name = src_ctrl.get(
            "nameForTargetDependencyResolutionOnly",
            default = identity,
        )
        result[identity] = name
    return result

def _new_from_parsed_json(dump_manifest, desc_manifest):
    """Returns the package information from the provided Swift package JSON \
    structures.

    Args:
        dump_manifest: A `dict` representing the parsed JSON from `swift
            package dump-package`.
        desc_manifest: A `dict` representing the parsed JSON from `swift
            package describe`.

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
    products = [
        _new_product_from_desc_json_map(prd_map)
        for prd_map in desc_manifest["products"]
    ]

    desc_targets_by_name = {
        target_map["name"]: target_map
        for target_map in desc_manifest["targets"]
    }
    targets = [
        _new_target_from_json_maps(
            dump_map = target_map,
            desc_map = desc_targets_by_name[target_map["name"]],
        )
        for target_map in dump_manifest["targets"]
    ]
    return _new(
        name = dump_manifest["name"],
        path = desc_manifest["path"],
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
        tools_version = None,
        platforms = [],
        dependencies = [],
        products = [],
        targets = []):
    """Returns a `struct` representing information about a Swift package.

    Args:
        name: The name of the Swift package (`string`).
        path: The path to the Swift package (`string`).
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

def _new_dependency(identity, name, type, url, requirement):
    """Creates a `struct` representing an external dependency for a Swift \
    package.

    Args:
        identity: The identifier for the external depdendency (`string`).
        name: The name used for package reference resolution (`string`).
        type: Type type of external dependency (`string`).
        url: The URL of the external dependency (`string`).
        requirement: A `struct` as returned by \
            `pkginfos.new_dependency_requirement()`.

    Returns:
        A `struct` representing an external dependency.
    """
    return struct(
        identity = identity,
        name = pkginfo_dependencies.normalize_name(name),
        type = type,
        url = url,
        requirement = requirement,
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

def _new_product_reference(product_name, dep_name):
    """Creates a product reference.

    Args:
        product_name: The name of the product (`string`).
        dep_name: The name of the external dependency (`string`).

    Returns:
        A `struct` representing a product reference.
    """
    return struct(
        product_name = product_name,
        dep_name = dep_name,
    )

def _new_by_name_reference(name):
    """Creates a by-name reference.

    Args:
        name: The name of a target or product (`string`).

    Returns:
        A `struct` representing a by-name reference.
    """
    return struct(
        name = name,
    )

def _new_target_reference(target_name):
    """Creates a target reference.

    Args:
        target_name: The name of a target (`string`).

    Returns:
        A `struct` representing a target reference.
    """
    return struct(
        target_name = target_name,
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

# MARK: - Target

def _new_target(
        name,
        type,
        c99name,
        module_type,
        path,
        sources,
        dependencies,
        exclude_paths = [],
        source_paths = None,
        clang_settings = None,
        swift_settings = None,
        linker_settings = None,
        public_hdrs_path = None,
        artifact_download_info = None,
        product_memberships = []):
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
        exclude_paths: Optional. A `list` of paths that should be excluded as
            specified by the Swift package manifest author.
        source_paths: Optional. A `list` of paths (`string` values) specified by
            the Swift package manfiest author.
        clang_settings: Optional. A `struct` as returned by `pkginfos.new_clang_settings`.
        swift_settings: Optional. A `struct` as returned by `pkginfos.new_swift_settings`.
        linker_settings: Optional. A `struct` as returned by `pkginfos.new_linker_settings`.
        public_hdrs_path: Optional. A `string`.
        artifact_download_info: Optional. A `struct` as returned by
            `pkginfos.new_artifact_download_info`.
        product_memberships: Optional. A `list` of product names that this
            target is referenced by.

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
    return struct(
        name = name,
        type = type,
        c99name = c99name,
        module_type = module_type,
        path = path,
        sources = sources,
        dependencies = dependencies,
        exclude_paths = exclude_paths,
        source_paths = normalized_src_paths,
        clang_settings = clang_settings,
        swift_settings = swift_settings,
        linker_settings = linker_settings,
        public_hdrs_path = public_hdrs_path,
        artifact_download_info = artifact_download_info,
        product_memberships = product_memberships,
    )

# MARK: - Build Settings

def _new_build_setting_condition(platforms = None, configuration = None):
    """Create a build setting condition.

    Args:
        platforms: Optional. A `list` of platform names as `string` values.
        configuration: Optional. The name of an SPM configuration as a `string`
            value.

    Returns:
        A `struct` representing build setting condition.
    """
    if platforms == None and configuration == None:
        return None
    if platforms != None:
        for platform in platforms:
            validations.in_list(
                spm_platforms.all_values,
                platform,
                "Unrecognized platform. platform:",
            )

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
    """Create a clang setting data struct.

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
    for bs in build_settings:
        if bs.kind == build_setting_kinds.define:
            defines.append(bs)
        elif bs.kind == build_setting_kinds.unsafe_flags:
            unsafe_flags.append(bs)
        else:
            # We do not recognize the setting.
            pass
    if len(defines) == 0 and len(unsafe_flags) == 0:
        return None
    return struct(
        defines = defines,
        unsafe_flags = unsafe_flags,
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

# MARK: - Constants

target_types = struct(
    binary = "binary",
    executable = "executable",
    library = "library",
    plugin = "plugin",
    regular = "regular",
    system = "system-target",
    test = "test",
    all_values = [
        "binary",
        "executable",
        "library",
        "plugin",
        "regular",
        "system-target",
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
)

# MARK: - API Definition

pkginfos = struct(
    get = _get,
    new = _new,
    new_artifact_download_info = _new_artifact_download_info,
    new_build_setting_condition = _new_build_setting_condition,
    new_build_setting = _new_build_setting,
    new_by_name_reference = _new_by_name_reference,
    new_clang_settings = _new_clang_settings,
    new_dependency = _new_dependency,
    new_dependency_requirement = _new_dependency_requirement,
    new_from_parsed_json = _new_from_parsed_json,
    new_library_type = _new_library_type,
    new_linker_settings = _new_linker_settings,
    new_platform = _new_platform,
    new_product = _new_product,
    new_product_reference = _new_product_reference,
    new_product_type = _new_product_type,
    new_swift_settings = _new_swift_settings,
    new_target = _new_target,
    new_target_dependency = _new_target_dependency,
    new_target_reference = _new_target_reference,
    new_version_range = _new_version_range,
)
