"""Module for creating Bazel declarations to build a Swift package."""

load(":package_infos.bzl", "module_types")
load(":pkginfo_targets.bzl", "pkginfo_targets")

def _new(pkg_info):
    decls = []

    # Generate declarations for targets
    for target in pkg_info.targets:
        decls.extend(_decls_for_target(target))

    # Generate declarations for products as alias

    return decls

def _decls_for_target(target):
    if target.module_type == module_types.clang:
        return _decls_for_clang_target(target)
    elif target.module_type == module_types.swift:
        return _decls_for_swift_target(target)
    elif target.module_type == module_types.system_library:
        return _decls_for_system_library_target(target)
    fail("Unrecognized module type.", target.module_type)

# MARK: - Clang

# TODO(chuck): Remove unused-variable directives

# buildifier: disable=unused-variable
def _decls_for_clang_target(target):
    # TODO(chuck): IMPLEMENT ME!
    return []

# MARK: - Swift

def _decls_for_swift_target(target):
    decls = []
    if target.type == target_types.library:
        decls.append(_swift_library_from_target(target))
    elif target.type == target_types.executable:
        # TODO(chuck): IMPLEMENT ME!
        pass
    else:
        fail("Unrecognized target type for a Swift target.", target.type)

    return decls

def _swift_library_from_target(target):
    return build_decls.new(
        kind = "swift_library",
        name = target.name,
        attrs = {
            "deps": pkginfo_targets.deps(target),
            "module_name": target.c99name,
            "srcs": pkginfo_targets.srcs(target),
            "visibility": ["//visibility:public"],
        },
    )

# MARK: - System Library

# buildifier: disable=unused-variable
def _decls_for_system_library_target(target):
    # TODO(chuck): IMPLEMENT ME!
    return []

swiftpkg_bld_decls = struct(
    new = _new,
)
