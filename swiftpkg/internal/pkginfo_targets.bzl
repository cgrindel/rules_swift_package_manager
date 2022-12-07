"""Module for generating data from targets created by `package_infos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")

def _get(targets, name, fail_if_not_found = True):
    """Retrieves the target with the given name from a list of targets.

    Args:
        targets: A `list` of target `struct` values as returned by
            `package_infos.new_target`.
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

def make_pkginfo_targets(bazel_labels = bazel_labels):
    """Create a `pkginfo_targets` module.

    Args:
        bazel_labels: The module to be used for creating and resolving labels.

    Returns:
        A `struct` representing the `pkginfo_targets` module.
    """

    def _bazel_label(target):
        """Create a Bazel label string from a target.

        Args:
            target: A `struct` as returned from `package_infos.new_target`.

        Returns:
            A `string` representing the label for the target.
        """
        return bazel_labels.normalize(
            bazel_labels.new(package = target.path, name = target.name),
        )

    return struct(
        get = _get,
        bazel_label = _bazel_label,
    )

pkginfo_targets = make_pkginfo_targets()
