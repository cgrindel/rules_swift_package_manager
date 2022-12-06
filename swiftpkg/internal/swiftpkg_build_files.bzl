"""Module for creating Bazel declarations to build a Swift package."""

load(":build_decls.bzl", "build_decls")
load(":build_files.bzl", "build_files")
load(":load_statements.bzl", "load_statements")
load(":package_infos.bzl", "module_types", "target_types")
load(":pkginfo_targets.bzl", "pkginfo_targets")

# def _new_for_targets(pkg_info, bzl_pkg_for_swift_pkg_targets = "_swiftpkg_targets"):
# bzl_pkg_for_swift_pkg_targets: Optional. The Bazel package under which
#     all Swift package targets will be defined.

def _new_for_targets(pkg_info):
    """Create a build file for the Swift package targets.

    Args:
        pkg_info: A `struct` as returned by `package_infos.new`.

    Returns:
        A `struct` as returned by `build_files.new` populated with declarations
        appropriate for the provide Swift package.
    """
    bld_files = [
        _decls_for_target(pkg_info, target)
        for target in pkg_info.targets
    ]
    return build_files.merge(*bld_files)

def _new_for_products(pkg_info, targets_build_file):
    # TODO(chuck): IMPLEMENT ME!
    pass

def _decls_for_target(pkg_info, target):
    if target.module_type == module_types.clang:
        return _decls_for_clang_target(target)
    elif target.module_type == module_types.swift:
        return _decls_for_swift_target(pkg_info, target)
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

def _decls_for_swift_target(pkg_info, target):
    if target.type == target_types.library or target.type == target_types.regular:
        load_stmts = [_swift_library_load_stmt]
        decls = [_swift_library_from_target(pkg_info, target)]
    elif target.type == target_types.executable:
        # TODO(chuck): IMPLEMENT ME!
        load_stmts = []
        decls = []
    else:
        fail("Unrecognized target type for a Swift target. type:", target.type)

    return build_files.new(
        load_stmts = load_stmts,
        decls = decls,
    )

def _swift_library_from_target(pkg_info, target):
    return build_decls.new(
        kind = _kinds.swift_library,
        name = target.name,
        attrs = {
            "deps": pkginfo_targets.deps(pkg_info, target),
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

_locations = struct(
    rules_swift = "@build_bazel_rules_swift//swift:swift.bzl",
)

_kinds = struct(
    swift_library = "swift_library",
)

_swift_library_load_stmt = load_statements.new(
    _locations.rules_swift,
    _kinds.swift_library,
)

swiftpkg_build_files = struct(
    new_for_targets = _new_for_targets,
    kinds = _kinds,
    locations = _locations,
)
