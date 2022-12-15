"""Module for resolving module names to labels."""

load("@bazel_skylib//lib:sets.bzl", "sets")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels", "lists")
load(":bazel_repo_names.bzl", "bazel_repo_names")

def _new_from_json(json_str):
    """Creates a module index from a JSON string.

    Args:
        json_str: A JSON `string` value.

    Returns:
        A `dict` where the keys are module names (`string`) and the values are
        `list` values that contain struct values as returned by `bazel_labels.new`.
    """
    orig_dict = json.decode(json_str)
    parsed_dict = {
        mod_name: [
            bazel_labels.parse(lbl_str)
            for lbl_str in lbl_strs
        ]
        for (mod_name, lbl_strs) in orig_dict.items()
    }
    return parsed_dict

def _find(
        module_index,
        module_name,
        preferred_repo_name = None,
        restrict_to_repo_names = []):
    """Finds a Bazel label that provides the specified module.

    Args:
        module_index: A `dict` as returned by `module_indexes.new_from_json`.
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
    labels = module_index.get(module_name, default = [])
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

module_indexes = struct(
    new_from_json = _new_from_json,
    find = _find,
)
