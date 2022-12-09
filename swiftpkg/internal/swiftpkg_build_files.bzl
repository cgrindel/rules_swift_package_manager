"""Module for creating Bazel declarations to build a Swift package."""

load(":build_decls.bzl", "build_decls")
load(":build_files.bzl", "build_files")
load(":lists.bzl", "lists")
load(":load_statements.bzl", "load_statements")
load(":pkginfo_target_deps.bzl", "pkginfo_target_deps")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":pkginfos.bzl", "module_types", "target_types")

# MARK: - Target Entry Point

def _new_for_target(pkg_info, target, repo_name):
    if target.module_type == module_types.clang:
        return _clang_target_build_file(target)
    elif target.module_type == module_types.swift:
        return _swift_target_build_file(pkg_info, target, repo_name)
    elif target.module_type == module_types.system_library:
        return _system_library_build_file(target)

    # GH046: Support plugins.
    return None

# MARK: - Swift Target

def _swift_target_build_file(pkg_info, target, repo_name):
    # GH046: Support plugins.
    if target.type == target_types.library or target.type == target_types.regular:
        load_stmts = [swift_library_load_stmt]
        decls = [_swift_library_from_target(pkg_info, target, repo_name)]
    elif target.type == target_types.executable:
        lib_name = "{}Lib".format(target.name)
        lib_decl = _swift_library_from_target(
            pkg_info,
            target,
            repo_name,
            name = lib_name,
            c99name = lib_name,
        )
        bin_decl = _swift_binary_from_target(target, lib_name)
        load_stmts = [swift_binary_load_stmt]
        decls = [lib_decl, bin_decl]
    elif target.type == target_types.test:
        load_stmts = [swift_test_load_stmt]
        decls = [_swift_test_from_target(pkg_info, target, repo_name)]
    else:
        fail("Unrecognized target type for a Swift target. type:", target.type)

    return build_files.new(
        load_stmts = load_stmts,
        decls = decls,
    )

def _swift_library_from_target(pkg_info, target, repo_name, name = None, c99name = None):
    if name == None:
        name = target.name
    if c99name == None:
        c99name = target.c99name
    return build_decls.new(
        kind = swift_kinds.library,
        name = name,
        attrs = {
            "deps": [
                pkginfo_target_deps.bazel_label(pkg_info, td, repo_name)
                for td in target.dependencies
            ],
            "module_name": c99name,
            "srcs": target.sources,
            "visibility": ["//visibility:public"],
        },
    )

def _swift_binary_from_target(target, lib_name):
    return build_decls.new(
        kind = swift_kinds.binary,
        name = target.name,
        attrs = {
            "deps": [":{}".format(lib_name)],
            "module_name": target.c99name,
            "srcs": target.sources,
            "visibility": ["//visibility:public"],
        },
    )

def _swift_test_from_target(pkg_info, target, repo_name):
    return build_decls.new(
        kind = swift_kinds.test,
        name = target.name,
        attrs = {
            "deps": [
                pkginfo_target_deps.bazel_label(pkg_info, td, repo_name)
                for td in target.dependencies
            ],
            "module_name": target.c99name,
            "srcs": target.sources,
            "visibility": ["//visibility:public"],
        },
    )

# MARK: - Clang Targets

# GH009(chuck): Remove unused-variable directives

# buildifier: disable=unused-variable
def _clang_target_build_file(target):
    # GH009(chuck): Implement _clang_target_build_file
    return []

# MARK: - System Library Targets

# buildifier: disable=unused-variable
def _system_library_build_file(target):
    # GH009(chuck): Implement _system_library_build_file
    return []

# MARK: - Products Entry Point

def _new_for_products(pkg_info, repo_name):
    bld_files = lists.compact([
        _new_for_product(pkg_info, prod, repo_name)
        for prod in pkg_info.products
    ])
    return build_files.merge(*bld_files)

def _new_for_product(pkg_info, product, repo_name):
    prod_type = product.type
    if prod_type.is_executable:
        return _executable_product_build_file(pkg_info, product, repo_name)
    elif prod_type.is_library:
        return _library_product_build_file(pkg_info, product, repo_name)
    return None

def _executable_product_build_file(pkg_info, product, repo_name):
    # Retrieve the targets
    targets = [
        pkginfo_targets.get(pkg_info.targets, tname)
        for tname in product.targets
    ]

    targets_len = len(targets)
    if targets_len == 1:
        target = targets[0]
        if target.type == target_types.executable:
            # Create an alias to the binary target created in the target package.
            return build_files.new(
                decls = [
                    build_decls.new(
                        native_kinds.alias,
                        product.name,
                        attrs = {
                            "actual": pkginfo_targets.bazel_label(target, repo_name = repo_name),
                            "visibility": ["//visibility:public"],
                        },
                    ),
                ],
            )
        else:
            # Create the binary target here.
            return build_files.new(
                load_stmts = [load_statements.new(swift_location, swift_kinds.binary)],
                decls = [_swift_binary_from_product(product, target, repo_name)],
            )
    elif targets_len > 1:
        fail("Multiple targets specified for an executable product. name:", product.name)
    else:
        fail("Did not find any targets associated with product. name:", product.name)

def _library_product_build_file(pkg_info, product, repo_name):
    # Retrieve the targets
    targets = [
        pkginfo_targets.get(pkg_info.targets, tname)
        for tname in product.targets
    ]
    targets_len = len(targets)
    if targets_len == 0:
        fail("No targets specified for a library product. name:", product.name)
    elif targets_len > 1:
        fail("Multiple targets specified for a library product. name:", product.name)

    actual_target = targets[0]
    return build_files.new(
        decls = [
            build_decls.new(
                native_kinds.alias,
                product.name,
                attrs = {
                    "actual": pkginfo_targets.bazel_label(actual_target, repo_name),
                    "visibility": ["//visibility:public"],
                },
            ),
        ],
    )

def _swift_binary_from_product(product, dep_target, repo_name):
    return build_decls.new(
        kind = swift_kinds.binary,
        name = product.name,
        attrs = {
            "deps": [pkginfo_targets.bazel_label(dep_target, repo_name = repo_name)],
            "visibility": ["//visibility:public"],
        },
    )

# MARK: - Constants and API Definition

swift_location = "@build_bazel_rules_swift//swift:swift.bzl"

swift_kinds = struct(
    library = "swift_library",
    binary = "swift_binary",
    test = "swift_test",
)

swift_library_load_stmt = load_statements.new(
    swift_location,
    swift_kinds.library,
)

swift_binary_load_stmt = load_statements.new(
    swift_location,
    swift_kinds.library,
    swift_kinds.binary,
)

swift_test_load_stmt = load_statements.new(swift_location, swift_kinds.test)

native_kinds = struct(
    alias = "alias",
)

swiftpkg_build_files = struct(
    new_for_target = _new_for_target,
    new_for_products = _new_for_products,
)
