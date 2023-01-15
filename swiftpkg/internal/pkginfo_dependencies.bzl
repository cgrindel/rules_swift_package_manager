"""Module for managing external dependencies created by `pkginfos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")

def _get_by_name(deps, name):
    """Returns the external dependency with the matching name.

    Args:
        deps: A `list` of external dependency values as returned by
            `pkginfos.new_dependency`.
        name: The name of an external dependency as a `string`.

    Returns:
        The matching external dependency or `None`.
    """
    return lists.find(deps, lambda d: d.name == name)

pkginfo_dependencies = struct(
    get_by_name = _get_by_name,
)
