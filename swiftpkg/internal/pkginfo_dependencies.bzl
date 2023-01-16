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

pkginfo_dependencies = struct(
    get_by_name = _get_by_name,
    normalize_name = _normalize_name,
)
