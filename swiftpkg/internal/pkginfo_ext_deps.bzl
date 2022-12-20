"""Module for generating data from external dependencies created by `pkginfos`."""

load(":bazel_repo_names.bzl", "bazel_repo_names")

def _find_by_identity(ext_deps, identity, fail_if_not_found = True):
    for ext_dep in ext_deps:
        if ext_dep.identity == identity:
            return ext_dep
    if fail_if_not_found:
        fail("Failed to find external dependency with identity", identity)
    return None

def _bazel_repo_name(ext_dep):
    return bazel_repo_names.from_identity(ext_dep.identity)

pkginfo_ext_deps = struct(
    find_by_identity = _find_by_identity,
    bazel_repo_name = _bazel_repo_name,
)
