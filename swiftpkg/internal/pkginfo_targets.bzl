"""Module for generating data from targets created by `package_infos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")

# TODO(chuck): Add documentation.

def _get(targets, name, fail_if_not_found = True):
    for target in targets:
        if target.name == name:
            return target
    if fail_if_not_found:
        fail("Failed to find target. name:", name)
    return None

def make_pkginfo_targets(bazel_labels = bazel_labels):
    def _bazel_label(target):
        return bazel_labels.normalize(
            bazel_labels.new(package = target.path, name = target.name),
        )

    return struct(
        get = _get,
        bazel_label = _bazel_label,
    )

pkginfo_targets = make_pkginfo_targets()
