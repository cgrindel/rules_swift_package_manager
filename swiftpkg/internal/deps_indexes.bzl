"""Module for resolving module names to labels."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels", "lists")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":validations.bzl", "validations")

def _new_from_json(json_str):
    """Creates a module index from a JSON string.

    Args:
        json_str: A JSON `string` value.

    Returns:
        A `struct` that contains indexes for external dependencies.
    """
    orig_dict = json.decode(json_str)
    return _new(
        modules = [
            _new_module_from_dict(mod_dict)
            for mod_dict in orig_dict["modules"]
        ],
        products = [
            _new_product_from_dict(prod_dict)
            for prod_dict in orig_dict["products"]
        ],
        packages = [
            _new_package_from_dict(pkg_dict)
            for pkg_dict in orig_dict.get("packages", [])
        ],
    )

def _new(modules = [], products = [], packages = []):
    modules_by_name = {}
    modules_by_label = {}
    products_by_key = {}
    products_by_name = {}
    packages_by_id = {}

    # buildifier: disable=uninitialized
    def _add_module(m):
        entries = modules_by_name.get(m.name, [])
        entries.append(m)
        modules_by_name[m.name] = entries
        modules_by_label[m.label] = m
        if m.name != m.c99name:
            entries = modules_by_name.get(m.c99name, [])
            entries.append(m)
            modules_by_name[m.c99name] = entries

    # buildifier: disable=uninitialized
    def _add_product(p):
        key = _new_product_index_key(p.identity, p.name)
        products_by_key[key] = p
        prds = products_by_name.get(p.name, [])
        prds.append(p)
        products_by_name[p.name] = prds

    def _add_package(p):
        packages_by_id[p.identity] = p

    for module in modules:
        _add_module(module)
    for product in products:
        _add_product(product)
    for package in packages:
        _add_package(package)

    return struct(
        modules_by_name = modules_by_name,
        modules_by_label = modules_by_label,
        products_by_key = products_by_key,
        products_by_name = products_by_name,
        packages_by_id = packages_by_id,
    )

def _new_module_from_dict(mod_dict):
    modulemap_label = None
    modulemap_label_str = mod_dict.get("modulemap_label", "")
    if modulemap_label_str != "":
        modulemap_label = bazel_labels.parse(modulemap_label_str)

    return _new_module(
        name = mod_dict["name"],
        c99name = mod_dict["c99name"],
        src_type = mod_dict.get("src_type", "unknown"),
        label = bazel_labels.parse(mod_dict["label"]),
        modulemap_label = modulemap_label,
        package_identity = mod_dict["package_identity"],
        product_memberships = mod_dict["product_memberships"],
    )

def _new_module(
        name,
        c99name,
        src_type,
        label,
        package_identity,
        product_memberships,
        modulemap_label = None):
    validations.in_list(
        src_types.all_values,
        src_type,
        "Unrecognized source type. type:",
    )
    return struct(
        name = name,
        c99name = c99name,
        src_type = src_type,
        label = label,
        modulemap_label = modulemap_label,
        package_identity = package_identity,
        product_memberships = product_memberships,
    )

def _new_product_from_dict(prd_dict):
    return _new_product(
        identity = prd_dict["identity"],
        name = prd_dict["name"],
        type = prd_dict["type"],
        label = bazel_labels.parse(prd_dict["label"]),
    )

def _new_product(identity, name, type, label):
    return struct(
        identity = identity,
        name = name,
        type = type,
        label = label,
    )

def _new_package(identity, name, remote_pkg = None, local_pkg = None):
    return struct(
        identity = identity,
        name = name,
        remote_pkg = remote_pkg,
        local_pkg = local_pkg,
    )

def _new_remote_package(remote, commit, version = None, branch = None, patch = None):
    return struct(
        remote = remote,
        commit = commit,
        version = version,
        branch = branch,
        patch = patch,
    )

def _new_local_package(path):
    return struct(
        path = path,
    )

def _new_patch(files, args = None, cmds = None, win_cmds = None, tool = None):
    return struct(
        files = files,
        args = args,
        cmds = cmds,
        win_cmds = win_cmds,
        tool = tool,
    )

def _new_patch_from_dict(patch_dict):
    if patch_dict == None:
        return None
    return _new_patch(
        files = patch_dict.get("files"),
        args = patch_dict.get("args"),
        cmds = patch_dict.get("cmds"),
        win_cmds = patch_dict.get("win_cmds"),
        tool = patch_dict.get("tool"),
    )

def _new_package_from_dict(pkg_dict):
    remote_pkg = None
    remote_dict = pkg_dict.get("remote")
    if remote_dict != None:
        remote_pkg = _new_remote_package(
            remote = remote_dict["remote"],
            commit = remote_dict["commit"],
            version = remote_dict.get("version"),
            branch = remote_dict.get("branch"),
            patch = _new_patch_from_dict(remote_dict.get("patch")),
        )
    local_pkg = None
    local_dict = pkg_dict.get("local")
    if local_dict != None:
        local_pkg = _new_local_package(path = local_dict["path"])
    return _new_package(
        identity = pkg_dict["identity"],
        name = pkg_dict["name"],
        remote_pkg = remote_pkg,
        local_pkg = local_pkg,
    )

def _modulemap_label_for_module(module):
    return bazel_labels.new(
        name = pkginfo_targets.modulemap_label_name(module.label.name),
        repository_name = module.label.repository_name,
        package = module.label.package,
    )

def _labels_for_module(module):
    """Returns the dep labels that should be used for a module.

    Args:
        module: The dependent module (`struct` as returned by
            `dep_indexes.new_module`).

    Returns:
        A `list` of Bazel label `struct` values as returned by `bazel_labels.new`,
    """
    labels = [module.label]

    if module.src_type == src_types.objc:
        # If the dep is an objc, return the real Objective-C target, not the Swift
        # module alias. This is part of a workaround for Objective-C modules not
        # being able to `@import` modules from other Objective-C modules.
        # See `swiftpkg_build_files.bzl` for more information.
        labels.append(_modulemap_label_for_module(module))

    elif (module.src_type == src_types.swift and
          module.modulemap_label != None):
        # If an Objc module wants to @import a Swift module, it will need the
        # modulemap target.
        labels.append(module.modulemap_label)

    return labels

def _get_module(deps_index, label):
    """Return the module associated with the specified label.

    Args:
        deps_index: A `dict` as returned by `deps_indexes.new_from_json`.
        label: A `struct` as returned by `bazel_labels.new` or a `string` value
            that can be parsed into a Bazel label.

    Returns:
        If found, a module `struct` as returned by `deps_indexes.new_module`.
        Otherwise, `None`.
    """
    if type(label) == "string":
        label = bazel_labels.parse(label)
    return deps_index.modules_by_label.get(label)

def _modules_for_product(deps_index, product):
    """Returns the modules associated with the product.

    Args:
        deps_index: A `dict` as returned by `deps_indexes.new_from_json`.
        product: A `struct` as returned by `deps_indexes.new_product`.

    Returns:
        A `list` of the modules associated with the product.
    """
    return lists.flatten(lists.compact([
        _get_module(deps_index, product.label),
    ]))

def _new_product_index_key(identity, name):
    return identity.lower() + "|" + name

def _new_product_index_key_for_product(product):
    if product == None:
        return None
    return _new_product_index_key(product.identity, product.name)

def _get_product(deps_index, identity, name):
    """Retrieves the product based upon the identity and the name.

    Args:
        deps_index: A `dict` as returned by `deps_indexes.new_from_json`.
        identity: The dependency identity as a `string`.
        name: The product name as a `string`.

    Returns:
        A product `struct` as returned by `deps_indexes.new_product`. If not
        found, returns `None`.
    """
    key = _new_product_index_key(identity, name)
    return deps_index.products_by_key.get(key)

def _new_ctx(deps_index, preferred_repo_name = None, restrict_to_repo_names = []):
    """Create a new context struct that encapsulates a dependency index along with \
    select lookup criteria.

    Args:
        deps_index: A `dict` as returned by `deps_indexes.new_from_json`.
        preferred_repo_name: Optional. If a target in this repository provides
            the module, prefer it.
        restrict_to_repo_names: Optional. A `list` of repository names to
            restrict the match.

    Returns:
        A `struct` that encapsulates a module index along with select lookup
        criteria.
    """
    return struct(
        deps_index = deps_index,
        preferred_repo_name = preferred_repo_name,
        restrict_to_repo_names = restrict_to_repo_names,
    )

src_types = struct(
    unknown = "unknown",
    swift = "swift",
    clang = "clang",
    objc = "objc",
    binary = "binary",
    all_values = [
        "unknown",
        "swift",
        "clang",
        "objc",
        "binary",
    ],
)

deps_indexes = struct(
    get_product = _get_product,
    get_module = _get_module,
    labels_for_module = _labels_for_module,
    modules_for_product = _modules_for_product,
    new = _new,
    new_ctx = _new_ctx,
    new_from_json = _new_from_json,
    new_module = _new_module,
    new_product = _new_product,
    new_product_index_key = _new_product_index_key,
    new_product_index_key_for_product = _new_product_index_key_for_product,
)
