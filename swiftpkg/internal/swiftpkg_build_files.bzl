"""Module for creating Bazel declarations to build a Swift package."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
load(":build_decls.bzl", "build_decls")
load(":build_files.bzl", "build_files")
load(":load_statements.bzl", "load_statements")
load(":pkginfo_target_deps.bzl", "pkginfo_target_deps")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":pkginfos.bzl", "module_types", "target_types")

# MARK: - Target Entry Point

def _new_for_target(pkg_ctx, target):
    if target.module_type == module_types.clang:
        return _clang_target_build_file(target)
    elif target.module_type == module_types.swift:
        return _swift_target_build_file(pkg_ctx, target)
    elif target.module_type == module_types.system_library:
        return _system_library_build_file(target)

    # GH046: Support plugins.
    return None

# MARK: - Swift Target

def _swift_target_build_file(pkg_ctx, target):
    deps = [
        pkginfo_target_deps.bazel_label(pkg_ctx, td)
        for td in target.dependencies
    ]
    attrs = {
        # SPM directive instructing the code to build as if a Swift package.
        # https://github.com/apple/swift-package-manager/blob/main/Documentation/Usage.md#packaging-legacy-code
        "defines": ["SWIFT_PACKAGE"],
        "deps": deps,
        "module_name": target.c99name,
        "srcs": pkginfo_targets.srcs(target),
        "visibility": ["//visibility:public"],
    }

    # GH046: Support plugins.
    if lists.contains([target_types.library, target_types.regular], target.type):
        load_stmts = [swift_library_load_stmt]
        decls = [_swift_library_from_target(target, attrs)]
    elif target.type == target_types.executable:
        load_stmts = [swift_binary_load_stmt]
        decls = [_swift_binary_from_target(target, attrs)]
    elif target.type == target_types.test:
        load_stmts = [swift_test_load_stmt]
        decls = [_swift_test_from_target(target, attrs)]
    else:
        fail("Unrecognized target type for a Swift target. type:", target.type)

    return build_files.new(
        load_stmts = load_stmts,
        decls = decls,
    )

def _swift_library_from_target(target, attrs):
    return build_decls.new(
        kind = swift_kinds.library,
        name = pkginfo_targets.bazel_label_name(target),
        attrs = attrs,
    )

def _swift_binary_from_target(target, attrs):
    return build_decls.new(
        kind = swift_kinds.binary,
        name = pkginfo_targets.bazel_label_name(target),
        attrs = attrs,
    )

def _swift_test_from_target(target, attrs):
    return build_decls.new(
        kind = swift_kinds.test,
        name = pkginfo_targets.bazel_label_name(target),
        attrs = attrs,
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

    # GH046: Check for plugin product
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
