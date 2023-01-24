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
load(":repository_files.bzl", "repository_files")

# MARK: - Target Entry Point

def _new_for_target(repository_ctx, pkg_ctx, target):
    if target.module_type == module_types.clang:
        return _clang_target_build_file(repository_ctx, pkg_ctx, target)
    elif target.module_type == module_types.swift:
        return _swift_target_build_file(repository_ctx, pkg_ctx, target)
    elif target.module_type == module_types.system_library:
        return _system_library_build_file(target)
    elif target.module_type == module_types.binary:
        return _apple_dynamic_xcframework_import_build_file(target)

    # GH046: Support plugins.
    return None

# MARK: - Swift Target

def _swift_target_build_file(repository_ctx, pkg_ctx, target):
    deps = lists.flatten([
        pkginfo_target_deps.bazel_label_strs(pkg_ctx, td)
        for td in target.dependencies
    ])
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
        for bs in target.swift_settings.defines:
            attrs["defines"].extend(bs.value)
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
    repo_name = repository_ctx.name
    pkg_path = pkg_ctx.pkg_info.path

    # Absolute path to the target. This is typically used for filesystem
    # actions, not for values added to the cc_library or objc_library.
    target_path = paths.normalize(
        paths.join(pkg_path, target.path),
    )

    # Short path relative to Bazel output base. This is typically used when
    # adding a path to a copt or linkeropt.
    ext_repo_path = paths.join("external", repo_name)

    public_includes = []
    if target.public_hdrs_path != None:
        public_includes.append(
            paths.normalize(paths.join(target.path, target.public_hdrs_path)),
        )

    # If the Swift package manifest has explicit source paths, respect them.
    # (Be sure to include any explicitly specified include directories.)
    # Otherwise, use all of the source files under the target path.
    if target.source_paths != None:
        src_paths = [
            paths.normalize(paths.join(target_path, sp))
            for sp in target.source_paths
        ]

        # The public includes are already relative to the target.path.
        src_paths.extend([
            paths.normalize(paths.join(pkg_path, pi))
            for pi in public_includes
        ])
        src_paths = sets.to_list(sets.make(src_paths))
    else:
        src_paths = [target_path]

    exclude_paths = [
        paths.normalize(paths.join(target_path, ep))
        for ep in target.exclude_paths
    ]

    # Get a list of all of the source files
    all_srcs = []
    for sp in src_paths:
        all_srcs.extend(repository_files.list_files_under(
            repository_ctx,
            sp,
            exclude = exclude_paths,
        ))

    # Organize the source files
    # Be sure that the all_srcs and the public_includes that are passed to
    # `collect_files` are all absolute paths.  The relative_to option will
    # ensure that the output values are relative to the package path.
    organized_files = clang_files.collect_files(
        repository_ctx,
        all_srcs,
        target.c99name,
        public_includes = [
            paths.normalize(paths.join(pkg_path, pi))
            for pi in public_includes
        ],
        relative_to = pkg_path,
    )
    deps = lists.flatten([
        pkginfo_target_deps.bazel_label_strs(pkg_ctx, td)
        for td in target.dependencies
    ])

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

    hdrs = []
    srcs = []
    extra_hdr_dirs = []
    public_includes = organized_files.public_includes
    local_includes = []
    if len(organized_files.srcs) > 0:
        srcs.extend(organized_files.srcs)
    if len(organized_files.hdrs) > 0:
        hdrs.extend(organized_files.hdrs)
    if len(organized_files.private_includes) > 0:
        local_includes.extend(organized_files.private_includes)
    if target.clang_settings != None:
        if len(target.clang_settings.defines) > 0:
            # TODO(chuck): Support conditional
            for bs in target.clang_settings.defines:
                attrs["defines"].extend(bs.value)
        if len(target.clang_settings.hdr_srch_paths) > 0:
            # TODO(chuck): Support conditional
            hdr_srch_paths = lists.flatten([
                bs.value
                for bs in target.clang_settings.hdr_srch_paths
            ])
            local_includes.extend([
                paths.join(target.path, p)
                for p in hdr_srch_paths
            ])
    if target.linker_settings != None:
        # TODO(chuck): Support conditional
        if len(target.linker_settings.linked_libraries) > 0:
            linked_libraries = lists.flatten([
                bs.value
                for bs in target.linker_settings.linked_libraries
            ])
            linkopts = attrs.get("linkopts", default = [])
            linkopts.extend(["-l{}".format(ll) for ll in linked_libraries])
            attrs["linkopts"] = linkopts
        if len(target.linker_settings.linked_frameworks) > 0:
            # This is using a objc_library attr.
            linked_frameworks = lists.flatten([
                bs.value
                for bs in target.linker_settings.linked_frameworks
            ])
            sdk_frameworks = attrs.get("sdk_frameworks", default = [])
            sdk_frameworks.extend(linked_frameworks)
            attrs["sdk_frameworks"] = sdk_frameworks

    if len(local_includes) > 0:
        # The `includes` attribute adds includes as -isystem which propagates
        # to cc_XXX that depend upon the library. Providing includes as -I only
        # provides the includes for this target.
        # https://bazel.build/reference/be/c-cpp#cc_library.includes
        attrs["copts"].extend([
            "-I{}".format(paths.normalize(paths.join(ext_repo_path, inc)))
            for inc in sets.to_list(sets.make(local_includes))
        ])

        # If the target path is not everything (i.e., dot), then check for
        # local includes that are outside the target path. We need to add them
        # to the srcs so that they can be found.
        if target.path != ".":
            # Ensure that any header files that are outside of the target path are
            # included in the srcs.
            for li in local_includes:
                normalized_li = paths.normalize(li)
                if clang_files.is_under_path(normalized_li, target.path):
                    continue
                extra_hdr_dirs.append(normalized_li)

    for ehd in extra_hdr_dirs:
        abs_ehd = paths.normalize(paths.join(pkg_path, ehd))
        hdr_paths = repository_files.list_files_under(repository_ctx, abs_ehd)
        hdr_paths = [
            clang_files.relativize(hp, pkg_path)
            for hp in hdr_paths
            if clang_files.is_hdr(hp)
        ]
        srcs.extend(hdr_paths)

    public_includes_set = sets.make(public_includes)
    srcs_set = sets.make(srcs)
    if len(hdrs) > 0:
        attrs["hdrs"] = hdrs
        hdrs_set = sets.make(hdrs)
        srcs_set = sets.difference(srcs_set, hdrs_set)

    if sets.length(public_includes_set) > 0:
        attrs["includes"] = sets.to_list(public_includes_set)

    if sets.length(srcs_set) > 0:
        srcs = sets.to_list(srcs_set)
        attrs["srcs"] = srcs

    bzl_target_name = pkginfo_targets.bazel_label_name(target)
    if clang_files.has_objc_srcs(srcs):
        # Enable clang module support.
        # https://bazel.build/reference/be/objective-c#objc_library.enable_modules
        attrs["enable_modules"] = True
        attrs["module_name"] = target.c99name

        # There is a known issue with Objective-C library targets not
        # supporting the `@import` of modules defined in other Objective-C
        # targets. As a workaround, we will define two targets. One is the
        # `objc_library` target.  The other is a `swift_objc_module_alias`
        # target. This second target generates a Swift module that re-exports
        # the modules defined in the Objective-C. Any internal targets that
        # depend upon this module will reference the `objc_library`. Any
        # external targets that depend upon this module will reference the
        # `swift_library` generated by the `swift_objc_module_alias` macro.
        #
        # See `deps_indexes.bzl` for the logic that resolves the dependency
        # labels.
        # See `swift_objc_module_alias.bzl` for details on the re-export macro.
        load_stmts = [swiftpkg_objc_module_alias_load_stmt]
        objc_target_name = pkginfo_targets.objc_label_name(bzl_target_name)
        decls = [
            build_decls.new(objc_kinds.library, objc_target_name, attrs = attrs),
            build_decls.new(
                kind = swiftpkg_kinds.objc_module_alias,
                name = bzl_target_name,
                attrs = {
                    "deps": [":{}".format(objc_target_name)],
                    "module_names": [target.c99name],
                    "visibility": ["//visibility:public"],
                },
            ),
        ]
    else:
        load_stmts = []
        decls = [
            build_decls.new(clang_kinds.library, bzl_target_name, attrs = attrs),
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

# MARK: - Apple xcframework Targets

def _apple_dynamic_xcframework_import_build_file(target):
    load_stmts = [apple_dynamic_xcframework_import_load_stmt]
    glob = build_decls.new_fn_call(
        "glob",
        ["{tpath}/*.xcframework/**".format(tpath = target.path)],
    )
    decls = [
        build_decls.new(
            kind = apple_kinds.dynamic_xcframework_import,
            name = pkginfo_targets.bazel_label_name(target),
            attrs = {
                "xcframework_imports": glob,
            },
        ),
    ]
    return build_files.new(
        load_stmts = load_stmts,
        decls = decls,
    )

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
    # A library product can reference one or more Swift targets. Hence a
    # dependency on a library product is a shorthand for depend upon all of the
    # Swift targets that is associated with the product. There is no good
    # corollary for this in Bazel. A `filegroup` supports this concept for
    # `srcs` and `data`, but not `deps`. It would require a rule to provide
    # multiple providers possibly of the same type.
    #
    # To allow someone to ensure that the associated targets do build, we will
    # generate a build_test.

    # Retrieve the targets
    targets = [
        pkginfo_targets.get(pkg_info.targets, tname)
        for tname in product.targets
    ]
    if len(targets) == 0:
        fail("No targets specified for a library product. name:", product.name)
    target_labels = [
        bazel_labels.normalize(pkginfo_targets.bazel_label(target, repo_name))
        for target in targets
    ]
    return build_files.new(
        load_stmts = [skylib_build_test_load_stmt],
        decls = [
            build_decls.new(
                skylib_kinds.build_test,
                product.name + "BuildTest",
                attrs = {
                    "targets": target_labels,
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
    c_module = "swift_c_module",
)

swift_library_load_stmt = load_statements.new(
    swift_location,
    swift_kinds.library,
)

swift_binary_load_stmt = load_statements.new(
    swift_location,
    swift_kinds.binary,
)

swift_c_module_load_stmt = load_statements.new(
    swift_location,
    swift_kinds.c_module,
)

swift_test_load_stmt = load_statements.new(swift_location, swift_kinds.test)

clang_kinds = struct(
    library = "cc_library",
)

objc_kinds = struct(
    library = "objc_library",
)

native_kinds = struct(
    alias = "alias",
)

skylib_build_test_location = "@bazel_skylib//rules:build_test.bzl"

skylib_kinds = struct(
    build_test = "build_test",
)

skylib_build_test_load_stmt = load_statements.new(
    skylib_build_test_location,
    skylib_kinds.build_test,
)

swiftpkg_build_files = struct(
    new_for_target = _new_for_target,
    new_for_products = _new_for_products,
)

apple_kinds = struct(
    dynamic_xcframework_import = "apple_dynamic_xcframework_import",
)

apple_apple_location = "@build_bazel_rules_apple//apple:apple.bzl"

apple_dynamic_xcframework_import_load_stmt = load_statements.new(
    apple_apple_location,
    apple_kinds.dynamic_xcframework_import,
)

swiftpkg_kinds = struct(
    objc_module_alias = "swift_objc_module_alias",
)

swiftpkg_build_defs_location = "@cgrindel_swift_bazel//swiftpkg:build_defs.bzl"

swiftpkg_objc_module_alias_load_stmt = load_statements.new(
    swiftpkg_build_defs_location,
    swiftpkg_kinds.objc_module_alias,
)
