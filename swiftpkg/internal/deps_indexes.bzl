"""Module for resolving module names to labels."""

load("@bazel_skylib//lib:sets.bzl", "sets")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels", "lists")
load(":bazel_repo_names.bzl", "bazel_repo_names")

def _new_from_json(json_str):
    """Creates a module index from a JSON string.

    Args:
        json_str: A JSON `string` value.

    Returns:
        A `struct` that contains indexes for external dependencies.
    """
    orig_dict = json.decode(json_str)
    orig_modules_dict = orig_dict["modules"]
    modules_dict = {
        mod_name: [
            bazel_labels.parse(lbl_str)
            for lbl_str in lbl_strs
        ]
        for (mod_name, lbl_strs) in orig_modules_dict.items()
    }
    orig_products_dict = orig_dict["products"]
    products_dict = {
        key: _new_product_from_dict(prd_dict)
        for (key, prd_dict) in orig_products_dict.items()
    }
    return struct(
        modules = modules_dict,
        products = products_dict,
    )

def _new(modules = {}, products = {}):
    return struct(
        modules = modules,
        products = products,
    )

def _new_product_from_dict(prd_dict):
    return _new_product(
        identity = prd_dict["identity"],
        name = prd_dict["name"],
        type = prd_dict["type"],
        target_labels = [
            bazel_labels.parse(lbl_str)
            for lbl_str in prd_dict["target_labels"]
        ],
    )

def _new_product(identity, name, type, target_labels):
    return struct(
        identity = identity,
        name = name,
        type = type,
        target_labels = target_labels,
    )

def _resolve_module_label(
        deps_index,
        module_name,
        preferred_repo_name = None,
        restrict_to_repo_names = []):
    """Finds a Bazel label that provides the specified module.

    Args:
        deps_index: A `dict` as returned by `deps_indexes.new_from_json`.
        module_name: The name of the module as a `string`
        preferred_repo_name: Optional. If a target in this repository provides
            the module, prefer it.
        restrict_to_repo_names: Optional. A `list` of repository names to
            restrict the match.

    Returns:
        A `struct` as returned by `bazel_labels.new`.
    """

    # Resolve for the module label by passing along the current repo
    # name (preferred) and a list of preferred repositories (those
    # listed in the package's dependencies).  If not found, then fail.
    labels = deps_index.modules.get(module_name, default = [])
    if len(labels) == 0:
        return None

    # If a repo name is provided, prefer that over any other matches
    if preferred_repo_name != None:
        preferred_repo_name = bazel_repo_names.normalize(preferred_repo_name)
        label = lists.find(labels, lambda l: l.repository_name == preferred_repo_name)
        if label != None:
            return label

    # If we are meant to only find a match in a set of repo names, then
    if len(restrict_to_repo_names) > 0:
        restrict_to_repo_names = [
            bazel_repo_names.normalize(rn)
            for rn in restrict_to_repo_names
        ]
        repo_names = sets.make(restrict_to_repo_names)
        label = lists.find(
            labels,
            lambda l: sets.contains(repo_names, l.repository_name),
        )
    else:
        label = labels[0]

    return label

def _new_product_index_key(identity, name):
    return identity.lower() + "|" + name

def _find_product(deps_index, identity, name):
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
    return deps_index.products.get(key)

def _resolve_product_labels(deps_index, identity, name):
    """Returns the Bazel labels that represent the specified product.

    Args:
        deps_index: A `dict` as returned by `deps_indexes.new_from_json`.
        identity: The dependency identity as a `string`.
        name: The product name as a `string`.

    Returns:
        A `list` of Bazel label `struct` values as returned by
        `bazel_labels.new`. If the product is not found, an empty `list` is
        returned.
    """
    product = _find_product(deps_index, identity, name)
    if product == None:
        return []
    return product.target_labels

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

def _resolve_module_label_with_ctx(deps_index_ctx, module_name):
    """Finds a Bazel label that provides the specified module.

    Args:
        deps_index_ctx: A `struct` as returned by `deps_indexes.new_ctx`.
        module_name: The name of the module as a `string`

    Returns:
        A `struct` as returned by `bazel_labels.new`.
    """
    return _resolve_module_label(
        deps_index = deps_index_ctx.deps_index,
        module_name = module_name,
        preferred_repo_name = deps_index_ctx.preferred_repo_name,
        restrict_to_repo_names = deps_index_ctx.restrict_to_repo_names,
    )

deps_indexes = struct(
    new = _new,
    new_ctx = _new_ctx,
    new_from_json = _new_from_json,
    new_product = _new_product,
    find_product = _find_product,
    resolve_module_label = _resolve_module_label,
    resolve_module_label_with_ctx = _resolve_module_label_with_ctx,
    resolve_product_labels = _resolve_product_labels,
)
