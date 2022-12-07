"""API for creating and loading Swift package information."""

# TODO(chuck): Rename package_infos to pkginfos to match pkginfo_targets.

load(":repository_utils.bzl", "repository_utils")

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
        `package_infos.new()`.
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
    prd_type = _new_product_type(
        executable = executable,
    )

    return _new_product(
        name = prd_map["name"],
        targets = prd_map["targets"],
        type = prd_type,
    )

def _new_target_dependency_from_dump_json_map(dep_map):
    by_name_list = dep_map.get("byName")
    by_name = _new_target_reference(by_name_list[0]) if by_name_list else None

    product = None
    product_list = dep_map.get("product")
    if product_list:
        product = _new_product_reference(
            product_name = product_list[0],
            dep_identity = product_list[1],
        )

    return _new_target_dependency(
        by_name = by_name,
        product = product,
    )

def _new_target_from_json_maps(dump_map, desc_map):
    dependencies = [
        _new_target_dependency_from_dump_json_map(d)
        for d in dump_map["dependencies"]
    ]
    return _new_target(
        name = dump_map["name"],
        type = dump_map["type"],
        c99name = desc_map["c99name"],
        module_type = desc_map["module_type"],
        path = desc_map["path"],
        sources = desc_map["sources"],
        dependencies = dependencies,
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
        `package_infos.new()`.
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
            `package_infos.new_platform()`.
        dependencies: A `list` of external depdency structs as created by
            `package_infos.new_dependency()`.
        products: A `list` of product structs as created by
            `package_infos.new_product()`.
        targets: A `list` of target structs as created by
            `package_infos.new_target()`.

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
            `package_infos.new_dependency_requirement()`.

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
            by `package_infos.new_version_range()`.

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

def _new_product_type(executable = False):
    """Creates a product type.

    Args:
        executable: A `bool` specifying whether the product is an executable.

    Returns:
        A `struct` representing a product type.
    """
    return struct(
        executable = executable,
    )

def _new_product(name, type, targets):
    """Creates a product.

    Args:
        name: The name of the product as a `string`.
        type: A `struct` as returned by `package_infos.new_product_type`.
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

def _new_target_reference(target_name):
    """Creates a target reference.

    Args:
        target_name: The name of the target (`string`).

    Returns:
        A `struct` representing a target reference.
    """
    return struct(
        target_name = target_name,
    )

def _new_target_dependency(by_name = None, product = None):
    """Creates a target dependency.

    Args:
        by_name: A `struct` as returned by
            `package_infos.new_target_reference()`.
        product: A `struct` as returned by
            `package_infos.new_product_reference()`.

    Returns:
        A `struct` representing a target dependency.
    """
    if by_name == None and product == None:
        fail("""\
A target dependency must have one of the following: `by_name` or a `product`.\
""")
    return struct(
        by_name = by_name,
        product = product,
    )

def _new_target(name, type, c99name, module_type, path, sources, dependencies):
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
            `package_infos.new_target_dependency()`.

    Returns:
        A `struct` representing a target in a Swift package.
    """
    return struct(
        name = name,
        type = type,
        c99name = c99name,
        module_type = module_type,
        path = path,
        sources = sources,
        dependencies = dependencies,
    )

target_types = struct(
    executable = "executable",
    library = "library",
    regular = "regular",
    system = "system-target",
    test = "test",
)

module_types = struct(
    clang = "ClangTarget",
    swift = "SwiftTarget",
    system_library = "SystemLibraryTarget",
)

package_infos = struct(
    get = _get,
    new = _new,
    new_from_parsed_json = _new_from_parsed_json,
    new_platform = _new_platform,
    new_dependency = _new_dependency,
    new_dependency_requirement = _new_dependency_requirement,
    new_version_range = _new_version_range,
    new_product = _new_product,
    new_product_type = _new_product_type,
    new_product_reference = _new_product_reference,
    new_target_reference = _new_target_reference,
    new_target_dependency = _new_target_dependency,
    new_target = _new_target,
)
