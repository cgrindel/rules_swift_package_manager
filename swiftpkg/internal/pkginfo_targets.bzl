"""Module for generating data from targets created by `pkginfos`."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")

def _get(targets, name, fail_if_not_found = True):
    """Retrieves the target with the given name from a list of targets.

    Args:
        targets: A `list` of target `struct` values as returned by
            `pkginfos.new_target`.
        name: The name of a target as a `string`.
        fail_if_not_found: Optional. A `bool` that determines whether to fail
            (True) or return `None` (False) if a target is not found.

    Returns:
        A target `struct` if a match is found. Otherwise, it fails or returns
        `None` depending upon the value of `fail_if_not_found`.
    """
    for target in targets:
        if target.name == name:
            return target
    if fail_if_not_found:
        fail("Failed to find target. name:", name)
    return None

def _srcs(target):
    """Returns the sources formatted for inclusion in a Bazel target's `srcs` attribute.

    Args:
        target: A `struct` as returned from `pkginfos.new_target`.

    Returns:
        A `list` of `string` values representing the path to source files for the target.
    """
    if target.path == ".":
        return target.sources
    return [
        paths.join(target.path, src)
        for src in target.sources
    ]

def _join_path(target, path):
    """Joins the provide path with that target.path. 

    If the target path is `.`, then the path input is returned without
    modification.

    Args:
        path: A path as a `string`.

    Returns:
        A `string` with the target path joined with the input path.
    """
    if target.path == ".":
        return path
    return paths.join(target.path, path)

def _bazel_label_name(target):
    """Returns the name of the Bazel label for the specified target.

    Args:
        target: A `struct` as returned from `pkginfos.new_target`.

    Returns:
        A `string` representing the Bazel label name.
    """
    basename = paths.basename(target.path)
    if basename == target.name:
        name = target.path
    else:
        name = _join_path(target, target.name)
    return name.replace("/", "_")

def make_pkginfo_targets(bazel_labels):
    """Create a `pkginfo_targets` module.

    Args:
        bazel_labels: The module to be used for creating and resolving labels.

    Returns:
        A `struct` representing the `pkginfo_targets` module.
    """

    def _bazel_label(target, repo_name = None):
        """Create a Bazel label string from a target.

        Args:
            target: A `struct` as returned from `pkginfos.new_target`.
            repo_name: The name of the repository as a `string`. This must be
                provided if the module is being used outside of a BUILD thread.

        Returns:
            A `struct`, as returned by `bazel_labels.new`, representing the
            label for the target.
        """
        return bazel_labels.new(
            repository_name = repo_name,
            package = "",
            name = _bazel_label_name(target),
        )

    return struct(
        bazel_label = _bazel_label,
        bazel_label_name = _bazel_label_name,
        get = _get,
        join_path = _join_path,
        srcs = _srcs,
    )

pkginfo_targets = make_pkginfo_targets(bazel_labels = bazel_labels)
