"""Module for creating Bazel declarations to build a Swift package."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:sets.bzl", "sets")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels", "lists")
load(":build_decls.bzl", "build_decls")
load(":build_files.bzl", "build_files")
load(":clang_files.bzl", "clang_files")
load(":load_statements.bzl", "load_statements")
load(":pkginfo_target_deps.bzl", "pkginfo_target_deps")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":pkginfos.bzl", "module_types", "target_types")

# MARK: - Target Entry Point

def _new_for_target(repository_ctx, pkg_ctx, target):
    if target.module_type == module_types.clang:
        return _clang_target_build_file(repository_ctx, pkg_ctx, target)
    elif target.module_type == module_types.swift:
        return _swift_target_build_file(repository_ctx, pkg_ctx, target)
    elif target.module_type == module_types.system_library:
        return _system_library_build_file(target)

    # GH046: Support plugins.
    return None

# MARK: - Swift Target

def _swift_target_build_file(repository_ctx, pkg_ctx, target):
    deps = [
        pkginfo_target_deps.bazel_label_str(pkg_ctx, td)
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

    # The rules_swift code links in developer libraries if the rule is marked testonly.
    # https://github.com/bazelbuild/rules_swift/blob/master/swift/internal/compiling.bzl#L1312-L1319
    is_test = _imports_xctest(repository_ctx, pkg_ctx, target)
    if is_test:
        attrs["testonly"] = True
    if target.swift_settings and len(target.swift_settings.defines) > 0:
        attrs["defines"].extend(target.swift_settings.defines)
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

def _imports_xctest(repository_ctx, pkg_ctx, target):
    target_path = paths.join(pkg_ctx.pkg_info.path, target.path)
    for src in target.sources:
        path = paths.join(target_path, src)
        file_contents = repository_ctx.read(path)
        if file_contents.find("import XCTest") > -1:
            return True
    return False

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

def _clang_target_build_file(repository_ctx, pkg_ctx, target):
    # TODO(chuck): Should I just use the srcs in the target?
    target_path = paths.normalize(
        paths.join(pkg_ctx.pkg_info.path, target.path),
    )
    organized_files = clang_files.collect_files(
        repository_ctx,
        [target_path],
        public_includes = None,
        remove_prefix = "{}/".format(pkg_ctx.pkg_info.path),
    )
    deps = [
        pkginfo_target_deps.bazel_label_str(pkg_ctx, td)
        for td in target.dependencies
    ]
    attrs = {
        # These flags are used by SPM when compiling clang modules.
        "copts": [
            # Enable 'blocks' language feature
            "-fblocks",
            # Synthesize retain and release calls for Objective-C pointers
            "-fobjc-arc",
            # Enable support for PIC macros
            "-fPIC",
            # Module name
            "-fmodule-name={}".format(target.c99name),
        ],
        # The SWIFT_PACKAGE define is a magical value that SPM uses when it
        # builds clang libraries that will be used as Swift modules.
        "defines": ["SWIFT_PACKAGE=1"],
        "deps": deps,
        "tags": ["swift_module={}".format(target.c99name)],
        "visibility": ["//visibility:public"],
    }
    repo_name = repository_ctx.name
    public_includes = []
    local_includes = []
    if target.public_hdrs_path != None:
        public_includes.append(target.public_hdrs_path)
    if len(organized_files.srcs) > 0:
        attrs["srcs"] = organized_files.srcs
    if len(organized_files.hdrs) > 0:
        attrs["hdrs"] = organized_files.hdrs
    if len(organized_files.public_includes) > 0:
        public_includes.extend(organized_files.public_includes)
    if len(organized_files.private_includes) > 0:
        local_includes.extend(organized_files.private_includes)
    if target.clang_settings:
        if len(target.clang_settings.defines) > 0:
            attrs["defines"].extend(target.clang_settings.defines)
        if len(target.clang_settings.hdr_srch_paths) > 0:
            local_includes.extend(target.clang_settings.hdr_srch_paths)
    if target.linker_settings and len(target.linker_settings.linked_libraries) > 0:
        linkopts = attrs.get("linkopts", default = [])
        linkopts.extend([
            "-l{}".format(ll)
            for ll in target.linker_settings.linked_libraries
        ])
        attrs["linkopts"] = linkopts

    if len(public_includes) > 0:
        attrs["includes"] = sets.to_list(sets.make(public_includes))
    if len(local_includes) > 0:
        # The `includes` attribute adds includes as -isystem which propagates
        # to cc_XXX that depend upon the library. Providing includes as -I only
        # provides the includes for this target.
        # https://bazel.build/reference/be/c-cpp#cc_library.includes
        attrs["copts"].extend([
            "-I{}".format(paths.join("external", repo_name, inc))
            for inc in sets.to_list(sets.make(local_includes))
        ])

    load_stmts = []
    decls = [
        build_decls.new(
            kind = clang_kinds.library,
            name = pkginfo_targets.bazel_label_name(target),
            attrs = attrs,
        ),
    ]
    return build_files.new(
        load_stmts = load_stmts,
        decls = decls,
    )

# MARK: - System Library Targets

# GH009(chuck): Remove unused-variable directives

# buildifier: disable=unused-variable
def _system_library_build_file(target):
    # GH009(chuck): Implement _system_library_build_file
    return None

# MARK: - Products Entry Point

def _new_for_products(pkg_info, repo_name):
    bld_files = lists.compact([
        _new_for_product(pkg_info, prod, repo_name)
        for prod in pkg_info.products
    ])

    # If we did not generate any build files, return an empty one.
    if len(bld_files) == 0:
        return build_files.new()
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
            # If the alias name will have the same name as the target, then do not create the alias.
            label = pkginfo_targets.bazel_label(target, repo_name)
            if label.name == product.name:
                return None

            # Create an alias to the binary target created in the target package.
            return build_files.new(
                decls = [
                    build_decls.new(
                        native_kinds.alias,
                        product.name,
                        attrs = {
                            "actual": bazel_labels.normalize(label),
                            "visibility": ["//visibility:public"],
                        },
                    ),
                ],
            )
        else:
            # This is an old-style (pre-5.4) configuration where an executable
            # product references a regular target.
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

    # If the alias name will have the same name as the target, then do not create the alias.
    label = pkginfo_targets.bazel_label(actual_target, repo_name)
    if label.name == product.name:
        return None
    return build_files.new(
        decls = [
            build_decls.new(
                native_kinds.alias,
                product.name,
                attrs = {
                    "actual": bazel_labels.normalize(label),
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
            "deps": [bazel_labels.normalize(
                pkginfo_targets.bazel_label(dep_target, repo_name = repo_name),
            )],
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

clang_kinds = struct(
    library = "cc_library",
)

native_kinds = struct(
    alias = "alias",
)

swiftpkg_build_files = struct(
    new_for_target = _new_for_target,
    new_for_products = _new_for_products,
)
