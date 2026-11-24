"""Module for managing external dependencies created by `pkginfos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")

def _normalize_name(name):
    """Normalize the dependency (i.e., package) name.

    External dependencies can be looked up by `identity` which is derived from
    the URL or by name which can be assigned by the Package manifest author.
    Identity values are lowercase as returned by the dump JSON. To keep things
    consistent, we will ensure that name values are stored lowercase, as well.

    Args:
        name: The dependency/package name as a `string`.

    Returns:
        The normalized name as a `string`.
    """
    return name.lower()

def _get_by_name(deps, name):
    """Returns the external dependency with the matching name.

    Args:
        deps: A `list` of external dependency values as returned by
            `pkginfos.new_dependency`.
        name: The name of an external dependency as a `string`.

    Returns:
        The matching external dependency or `None`.
    """

    # Normalize the input name. The dependency name value should be normalized
    # already.
    normalized = _normalize_name(name)
    return lists.find(deps, lambda d: d.name == normalized)

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
            dep = _get_by_name(
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

pkginfo_dependencies = struct(
    get_by_name = _get_by_name,
    module_aliases_by_identity = _module_aliases_by_identity,
    normalize_name = _normalize_name,
)
