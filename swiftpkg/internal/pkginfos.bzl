"""API for creating and loading Swift package information."""

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

def _new_dependency_from_desc_json_map(dep_map):
    return _new_dependency(
        identity = dep_map["identity"],
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
            dep_identity = product_list[1],
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
    return _new_target(
        name = dump_map["name"],
        type = dump_map["type"],
        c99name = desc_map["c99name"],
        module_type = desc_map["module_type"],
        path = desc_map["path"],
        sources = desc_map["sources"],
        dependencies = dependencies,
        clang_settings = clang_settings,
        swift_settings = swift_settings,
        linker_settings = linker_settings,
        public_hdrs_path = dump_map.get("publicHeadersPath"),
    )

def _new_clang_settings_from_dump_json_list(dump_list):
    defines = []
    hdr_srch_paths = []
    for setting in dump_list:
        if setting["tool"] != "c":
            continue
        kind_map = setting.get("kind")
        if kind_map == None:
            continue
        define_map = kind_map.get("define")
        if define_map != None:
            for define in define_map.values():
                defines.append(define)
        hdr_srch_path_map = kind_map.get("headerSearchPath")
        if hdr_srch_path_map != None:
            hdr_srch_paths.extend(hdr_srch_path_map.values())

    if len(defines) == 0 and len(hdr_srch_paths) == 0:
        return None
    return _new_clang_settings(
        defines = defines,
        hdr_srch_paths = hdr_srch_paths,
    )

def _new_swift_settings_from_dump_json_list(dump_list):
    defines = []
    for setting in dump_list:
        if setting["tool"] != "swift":
            continue
        kind_map = setting.get("kind")
        if kind_map == None:
            continue
        define_map = kind_map.get("define")
        if define_map == None:
            continue
        for define in define_map.values():
            defines.append(define)

    if len(defines) == 0:
        return None
    return _new_swift_settings(
        defines = defines,
    )

def _new_linker_settings_from_dump_json_list(dump_list):
    linked_libraries = []
    for setting in dump_list:
        if setting["tool"] != "linker":
            continue
        kind_map = setting.get("kind")
        if kind_map == None:
            continue
        linked_library_map = kind_map.get("linkedLibrary")
        if linked_library_map == None:
            continue
        for linked_library in linked_library_map.values():
            linked_libraries.append(linked_library)

    if len(linked_libraries) == 0:
        return None
    return _new_linker_settings(
        linked_libraries = linked_libraries,
    )

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
    dependencies = [
        _new_dependency_from_desc_json_map(dep_map)
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

def _new_dependency(identity, type, url, requirement):
    """Creates a `struct` representing an external dependency for a Swift \
    package.

    Args:
        identity: The identifier for the external depdendency (`string`).
        type: Type type of external dependency (`string`).
        url: The URL of the external dependency (`string`).
        requirement: A `struct` as returned by \
            `pkginfos.new_dependency_requirement()`.

    Returns:
        A `struct` representing an external dependency.
    """
    return struct(
        identity = identity,
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

def _new_product_reference(product_name, dep_identity):
    """Creates a product reference.

    Args:
        product_name: The name of the product (`string`).
        dep_identity: The identity of the external dependency (`string`).

    Returns:
        A `struct` representing a product reference.
    """
    return struct(
        product_name = product_name,
        dep_identity = dep_identity,
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

def _new_target(
        name,
        type,
        c99name,
        module_type,
        path,
        sources,
        dependencies,
        clang_settings = None,
        swift_settings = None,
        linker_settings = None,
        public_hdrs_path = None):
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
        clang_settings: Optional. A `struct` as returned by `pkginfos.new_clang_settings`.
        swift_settings: Optional. A `struct` as returned by `pkginfos.new_swift_settings`.
        linker_settings: Optional. A `struct` as returned by `pkginfos.new_linker_settings`.
        public_hdrs_path: Optional. A `string`.

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
    return struct(
        name = name,
        type = type,
        c99name = c99name,
        module_type = module_type,
        path = path,
        sources = sources,
        dependencies = dependencies,
        clang_settings = clang_settings,
        swift_settings = swift_settings,
        linker_settings = linker_settings,
        public_hdrs_path = public_hdrs_path,
    )

def _new_clang_settings(defines, hdr_srch_paths):
    return struct(
        defines = defines,
        hdr_srch_paths = hdr_srch_paths,
    )

def _new_swift_settings(defines):
    return struct(
        defines = defines,
    )

def _new_linker_settings(linked_libraries):
    return struct(
        linked_libraries = linked_libraries,
    )

target_types = struct(
    executable = "executable",
    library = "library",
    plugin = "plugin",
    regular = "regular",
    system = "system-target",
    test = "test",
    all_values = [
        "executable",
        "library",
        "plugin",
        "regular",
        "system-target",
        "test",
    ],
)

module_types = struct(
    clang = "ClangTarget",
    plugin = "PluginTarget",
    swift = "SwiftTarget",
    system_library = "SystemLibraryTarget",
    all_values = [
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

pkginfos = struct(
    get = _get,
    new = _new,
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
