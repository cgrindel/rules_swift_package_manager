"""Module for generating data from external dependencies created by `pkginfos`."""

def _find_by_identity(ext_deps, identity, fail_if_not_found = True):
    for ext_dep in ext_deps:
        if ext_dep.identity == identity:
            return ext_dep
    if fail_if_not_found:
        fail("Failed to find external dependency with identity", identity)
    return None

pkginfo_ext_deps = struct(
    find_by_identity = _find_by_identity,
)
