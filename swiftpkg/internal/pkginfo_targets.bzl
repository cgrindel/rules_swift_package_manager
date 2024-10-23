"""Module for generating data from targets created by `pkginfos`."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")

_modulemap_suffix = "_modulemap"
_resource_bundle_suffix = "_resource_bundle"
_objc_resource_bundle_accessor_hdr_suffix = "_objc_resource_bundle_accessor_hdr"
_objc_resource_bundle_accessor_impl_suffix = "_objc_resource_bundle_accessor_impl"
_objc_resource_bundle_accessor_library_suffix = "_objc_resource_bundle_accessor_library"
_resource_bundle_accessor_suffix = "_resource_bundle_accessor"
_resource_bundle_infoplist_suffix = "_resource_bundle_infoplist"
_swift_hint_suffix = "_swift_hint"

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

def _get_by_label(targets, label, fail_if_not_found = True):
    """Retrieves the target with the given name from a list of targets.

    Args:
        targets: A `list` of target `struct` values as returned by
            `pkginfos.new_target`.
        label: The Bazel label of a target as a `string`.
        fail_if_not_found: Optional. A `bool` that determines whether to fail
            (True) or return `None` (False) if a target is not found.

    Returns:
        A target `struct` if a match is found. Otherwise, it fails or returns
        `None` depending upon the value of `fail_if_not_found`.
    """
    for target in targets:
        if target.label == label:
            return target
    if fail_if_not_found:
        fail("Failed to find target. label:", label)
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

def _join_path_from_parts(target_path, path):
    if target_path == ".":
        return path
    return paths.join(target_path, path)

def _join_path(target, path):
    """Joins the provide path with that target.path.

    If the target path is `.`, then the path input is returned without
    modification.

    Args:
        target: A `struct` as returned from `pkginfos.new_target`.
        path: A path as a `string`.

    Returns:
        A `string` with the target path joined with the input path.
    """
    return _join_path_from_parts(target.path, path)

def _bazel_label_name_from_parts(target_name):
    """Create a Bazel label name from a target name.

    The logic in this function must stay in sync with BazelLabelFromTarget() in
    bazel_label.go.

    Args:
        target_name: The target's name as a `string`.

    Returns:
        A Bazel label name as a `string`.
    """
    return target_name + ".rspm"

def _bazel_label_name(target):
    """Returns the name of the Bazel label for the specified target.

    Args:
        target: A `struct` as returned from `pkginfos.new_target`.

    Returns:
        A `string` representing the Bazel label name.
    """
    return _bazel_label_name_from_parts(target.name)

def _modulemap_label_name(target_name):
    """Returns the name of the related `generate_modulemap` target.

    Args:
        target_name: The publicly advertised name for the `objc_library` target.

    Returns:
        The name of the `generate_modulemap` target as a `string`.
    """
    return target_name + _modulemap_suffix

def _is_modulemap_label(target_name):
    """Determines whether the name is a `generate_modulemap` target name.

    Args:
        target_name: The name to be evaluated as a `string`.

    Returns:
        A `bool` representing whether the input name is a `generate_modulemap`
        target.
    """
    return target_name.endswith(_modulemap_suffix)

def _swift_hint_label_name(target_name):
    """Returns the name of the related `swift_interopt_hint` target.

    Args:
        target_name: The publicly advertised name for the `cc_library` target.

    Returns:
        The name of the `swift_interopt_hint` target as a `string`.
    """
    return target_name + _swift_hint_suffix

def _resource_bundle_name(package_name, module_name):
    """Returns the `bundle_name` for the module.

    For Swift packages, it appears the bundle name is of the format
    `<package_name>_<module_name>`.

    Args:
        package_name: The package name.
        module_name: The module name.

    Returns:
        The `bundle_name` of the `apple_resource_bundle` as a `string`.
    """
    return package_name + "_" + module_name

def _resource_bundle_label_name(target_name):
    """Returns the name of the related `apple_resource_bundle` target.

    Args:
        target_name: The publicly advertised name for the Swift target.

    Returns:
        The name of the `apple_resource_bundle` as a `string`.
    """
    return target_name + _resource_bundle_suffix

def _objc_resource_bundle_accessor_hdr_label_name(target_name):
    """Returns the name of the related `objc_resource_bundle_accessor` target.

    Args:
        target_name: The publicly advertised name for the Swift target.

    Returns:
        The name of the `resource_bundle_accessor` as a `string`.
    """
    return target_name + _objc_resource_bundle_accessor_hdr_suffix

def _objc_resource_bundle_accessor_impl_label_name(target_name):
    """Returns the name of the related `objc_resource_bundle_accessor` target.

    Args:
        target_name: The publicly advertised name for the Swift target.

    Returns:
        The name of the `resource_bundle_accessor` as a `string`.
    """
    return target_name + _objc_resource_bundle_accessor_impl_suffix

def _objc_resource_bundle_accessor_library_label_name(target_name):
    """Returns the name of the related `objc_library` target.

    Args:
        target_name: The publicly advertised name for the Swift target.

    Returns:
        The name of the `objc_library` as a `string`.
    """
    return target_name + _objc_resource_bundle_accessor_library_suffix

def _resource_bundle_accessor_label_name(target_name):
    """Returns the name of the related `resource_bundle_accessor` target.

    Args:
        target_name: The publicly advertised name for the Swift target.

    Returns:
        The name of the `resource_bundle_accessor` as a `string`.
    """
    return target_name + _resource_bundle_accessor_suffix

def _resource_bundle_infoplist_label_name(target_name):
    """Returns the name of the related `resource_bundle_infoplist` target.

    Args:
        target_name: The publicly advertised name for the Swift target.

    Returns:
        The name of the `resource_bundle_infoplist` as a `string`.
    """
    return target_name + _resource_bundle_infoplist_suffix

def make_pkginfo_targets(bazel_labels):
    """Create a `pkginfo_targets` module.

    Args:
        bazel_labels: The module to be used for creating and resolving labels.

    Returns:
        A `struct` representing the `pkginfo_targets` module.
    """

    def _bazel_label_from_parts(target_name, repo_name = None):
        """Create a Bazel label string from a target information.

        Args:
            target_name: The target's name as a `string`.
            repo_name: The name of the repository as a `string`. This must be
                provided if the module is being used outside of a BUILD thread.

        Returns:
            A `struct`, as returned by `bazel_labels.new`, representing the
            label for the target.
        """
        return bazel_labels.new(
            repository_name = repo_name,
            package = "",
            name = _bazel_label_name_from_parts(target_name),
        )

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
        bazel_label_from_parts = _bazel_label_from_parts,
        bazel_label_name = _bazel_label_name,
        get = _get,
        get_by_label = _get_by_label,
        is_modulemap_label = _is_modulemap_label,
        join_path = _join_path,
        modulemap_label_name = _modulemap_label_name,
        objc_resource_bundle_accessor_hdr_label_name = _objc_resource_bundle_accessor_hdr_label_name,
        objc_resource_bundle_accessor_impl_label_name = _objc_resource_bundle_accessor_impl_label_name,
        objc_resource_bundle_accessor_library_label_name = _objc_resource_bundle_accessor_library_label_name,
        resource_bundle_accessor_label_name = _resource_bundle_accessor_label_name,
        resource_bundle_infoplist_label_name = _resource_bundle_infoplist_label_name,
        resource_bundle_label_name = _resource_bundle_label_name,
        resource_bundle_name = _resource_bundle_name,
        srcs = _srcs,
        swift_hint_label_name = _swift_hint_label_name,
    )

pkginfo_targets = make_pkginfo_targets(bazel_labels = bazel_labels)
