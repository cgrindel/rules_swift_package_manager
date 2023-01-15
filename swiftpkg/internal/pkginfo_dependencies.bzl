load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")

def _get_by_name(deps, name):
    return lists.find(deps, lambda d: d.name == name)

pkginfo_dependencies = struct(
    get_by_name = _get_by_name,
)
