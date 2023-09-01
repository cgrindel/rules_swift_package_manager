"""Module for creating Bazel declarations to build a Swift package."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels", "lists")
load(":bazel_apple_platforms.bzl", "bazel_apple_platforms")
load(":build_decls.bzl", "build_decls")
load(":build_files.bzl", "build_files")
load(":bzl_selects.bzl", "bzl_selects")
load(":load_statements.bzl", "load_statements")
load(":pkginfo_target_deps.bzl", "pkginfo_target_deps")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":pkginfos.bzl", "build_setting_kinds", "module_types", "pkginfos", "target_types")
load(":repository_files.bzl", "repository_files")
load(":starlark_codegen.bzl", scg = "starlark_codegen")

# MARK: - Target Entry Point

def _new_for_target(repository_ctx, pkg_ctx, target):
    if target.module_type == module_types.clang:
        return _clang_target_build_file(repository_ctx, pkg_ctx, target)
    elif target.module_type == module_types.swift:
        return _swift_target_build_file(repository_ctx, pkg_ctx, target)
    elif target.module_type == module_types.system_library:
        return _system_library_build_file(target)
    elif target.module_type == module_types.binary:
        # GH559: Allow client to control how binary targets are exposed.
        return _apple_static_xcframework_import_build_file(target)

    # GH046: Support plugins.
    return None

# MARK: - Swift Target

def _swift_target_build_file(repository_ctx, pkg_ctx, target):
    if target.swift_src_info == None:
        fail("Expected a `swift_src_info`. name: ", target.name)

    all_build_files = []
    bzl_target_name = pkginfo_targets.bazel_label_name(target)
    deps = lists.flatten([
        pkginfo_target_deps.bzl_select_list(pkg_ctx, td, depender_module_name = target.c99name)
        for td in target.dependencies
    ])

    attrs = {
        "deps": bzl_selects.to_starlark(deps),
        "module_name": target.c99name,
        "srcs": pkginfo_targets.srcs(target),
        "visibility": ["//visibility:public"],
    }
    defines = [
        # SPM directive instructing the code to build as if a Swift package.
        # https://github.com/apple/swift-package-manager/blob/main/Documentation/Usage.md#packaging-legacy-code
        "SWIFT_PACKAGE",
    ]
    copts = []

    # GH046: Support plugins.

    # Check if any of the sources indicate that the module will be used by
    # Objective-C code. If so, generate the bridge header file.
    if target.swift_src_info.has_objc_directive:
        attrs["generates_header"] = True

    # The rules_swift code links in developer libraries if the rule is marked testonly.
    # https://github.com/bazelbuild/rules_swift/blob/master/swift/internal/compiling.bzl#L1312-L1319
    if target.swift_src_info.imports_xctest:
        attrs["testonly"] = True

    if target.swift_settings != None:
        if len(target.swift_settings.defines) > 0:
            defines.extend(lists.flatten([
                bzl_selects.new_from_build_setting(bs)
                for bs in target.swift_settings.defines
            ]))
        if len(target.swift_settings.unsafe_flags) > 0:
            copts.extend(lists.flatten([
                bzl_selects.new_from_build_setting(bs)
                for bs in target.swift_settings.unsafe_flags
            ]))

    if len(defines) > 0:
        attrs["defines"] = bzl_selects.to_starlark(defines)
    if len(copts) > 0:
        attrs["copts"] = bzl_selects.to_starlark(copts)
    if len(target.resources) > 0:
        # Apparently, SPM provides a `Bundle.module` accessor. So, we do too.
        # https://stackoverflow.com/questions/63237395/generating-resource-bundle-accessor-type-bundle-has-no-member-module
        all_build_files.append(_apple_resource_bundle(
            repository_ctx,
            target,
            pkg_ctx.pkg_info.default_localization,
        ))
        attrs["srcs"].append(":{}".format(
            pkginfo_targets.resource_bundle_accessor_label_name(bzl_target_name),
        ))
        attrs["data"] = [
            ":{}".format(pkginfo_targets.resource_bundle_label_name(bzl_target_name)),
        ]

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
    all_build_files.append(build_files.new(
        load_stmts = load_stmts,
        decls = decls,
    ))

    # Generate a modulemap for the Swift module.
    if attrs.get("generates_header", False):
        all_build_files.append(_generate_modulemap_for_swift_target(target, deps))

    return build_files.merge(*all_build_files)

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
    clang_src_info = target.clang_src_info
    if clang_src_info == None:
        fail("Expected `clang_src_info` to not be None.")

    deps = lists.flatten([
        pkginfo_target_deps.bzl_select_list(
            pkg_ctx,
            td,
            depender_module_name = target.c99name,
        )
        for td in target.dependencies
    ])

    attrs = {
        "tags": ["swift_module={}".format(target.c99name)],
        "visibility": ["//visibility:public"],
    }

    def _set_if_not_empty(attr, list, transform_fn = None):
        if len(list) > 0:
            attrs[attr] = transform_fn(list) if transform_fn else list

    _set_if_not_empty("deps", deps, bzl_selects.to_starlark)
    _set_if_not_empty("hdrs", clang_src_info.hdrs)
    _set_if_not_empty("srcs", clang_src_info.srcs)
    _set_if_not_empty("includes", clang_src_info.public_includes)
    _set_if_not_empty("textual_hdrs", clang_src_info.textual_hdrs)

    defines = [
        # The SWIFT_PACKAGE define is a magical value that SPM uses when it
        # builds clang libraries that will be used as Swift modules.
        "SWIFT_PACKAGE=1",
    ]

    # These flags are used by SPM when compiling clang modules.
    copts = [
        # Enable 'blocks' language feature
        "-fblocks",
        # Synthesize retain and release calls for Objective-C pointers
        "-fobjc-arc",
        # Enable support for PIC macros
        "-fPIC",
        # Module name
        "-fmodule-name={}".format(target.c99name),
    ]

    local_includes = [
        bzl_selects.new(value = p, kind = _condition_kinds.private_includes)
        for p in clang_src_info.private_includes
    ]

    if target.clang_settings != None:
        defines.extend(lists.flatten([
            bzl_selects.new_from_build_setting(
                bs,
                # Define values can contain spaces. Bazel requires that they
                # are already escaped.
                values_map_fn = scg.normalize_define_value,
            )
            for bs in target.clang_settings.defines
        ]))

        # Need to convert the headerSearchPaths to be relative to the
        # target path. We also do not want to lose any conditions that may
        # be attached.
        hsp_bss = [
            pkginfos.new_build_setting(
                kind = bs.kind,
                values = [
                    paths.join(target.path, p)
                    for p in bs.values
                ],
                condition = bs.condition,
            )
            for bs in target.clang_settings.hdr_srch_paths
        ]
        local_includes.extend(lists.flatten([
            bzl_selects.new_from_build_setting(bs)
            for bs in hsp_bss
        ]))

        copts.extend(lists.flatten([
            bzl_selects.new_from_build_setting(bs)
            for bs in target.clang_settings.unsafe_flags
        ]))

    linkopts = []
    if target.linker_settings != None:
        linkopts.extend(lists.flatten([
            bzl_selects.new_from_build_setting(bs)
            for bs in target.linker_settings.linked_libraries
        ]))
        linkopts.extend(lists.flatten([
            bzl_selects.new_from_build_setting(bs)
            for bs in target.linker_settings.linked_frameworks
        ]))

    if len(linkopts) > 0:
        attrs["linkopts"] = bzl_selects.to_starlark(
            linkopts,
            kind_handlers = {
                _condition_kinds.linked_library: bzl_selects.new_kind_handler(
                    transform = lambda ll: "-l{}".format(ll),
                ),
                _condition_kinds.linked_framework: bzl_selects.new_kind_handler(
                    transform = lambda f: "-framework {}".format(f),
                ),
            },
        )

    # Short path relative to Bazel output base. This is typically used when
    # adding a path to a copt or linkeropt.
    ext_repo_path = paths.join("external", repository_ctx.name)

    copts.extend(local_includes)

    # The `includes` attribute adds includes as -isystem which propagates
    # to cc_XXX that depend upon the library.  Providing includes as -I
    # only provides the includes for this target.
    # https://bazel.build/reference/be/c-cpp#cc_library.includes
    local_includes_transform = lambda p: "-I{}".format(
        paths.normalize(paths.join(ext_repo_path, p)),
    )
    attrs["copts"] = bzl_selects.to_starlark(
        copts,
        kind_handlers = {
            _condition_kinds.header_search_path: bzl_selects.new_kind_handler(
                transform = local_includes_transform,
            ),
            _condition_kinds.private_includes: bzl_selects.new_kind_handler(
                transform = local_includes_transform,
            ),
        },
    )

    attrs["defines"] = bzl_selects.to_starlark(defines)

    bzl_target_name = target.label.name

    if target.objc_src_info != None:
        # Enable clang module support.
        # https://bazel.build/reference/be/objective-c#objc_library.enable_modules
        attrs["enable_modules"] = True
        attrs["module_name"] = target.c99name

        sdk_framework_bzl_selects = []
        for sf in target.objc_src_info.builtin_frameworks:
            platform_conditions = bazel_apple_platforms.for_framework(sf)
            for pc in platform_conditions:
                sdk_framework_bzl_selects.append(
                    bzl_selects.new(
                        value = sf,
                        kind = _condition_kinds.sdk_frameworks,
                        condition = pc,
                    ),
                )
        attrs["sdk_frameworks"] = bzl_selects.to_starlark(
            sdk_framework_bzl_selects,
        )

        modulemap_deps = _collect_modulemap_deps(deps)

        # There is a known issue with Objective-C library targets not
        # supporting the `@import` of modules defined in other Objective-C
        # targets. As a workaround, we will define two targets. One is the
        # `objc_library` target.  The other is a `generate_modulemap`
        # target. This second target generates a `module.modulemap` file and
        # provides information about that generated file to `objc_library`
        # targets.
        #
        # See `deps_indexes.bzl` for the logic that resolves the dependency
        # labels.
        # See `generate_modulemap.bzl` for details on the modulemap generation.
        # See `//swiftpkg/tests/generate_modulemap_tests` package for a usage
        # example.
        load_stmts = [swiftpkg_generate_modulemap_load_stmt]
        modulemap_target_name = pkginfo_targets.modulemap_label_name(bzl_target_name)
        decls = [
            build_decls.new(objc_kinds.library, bzl_target_name, attrs = attrs),
            build_decls.new(
                kind = swiftpkg_kinds.generate_modulemap,
                name = modulemap_target_name,
                attrs = {
                    "deps": bzl_selects.to_starlark(modulemap_deps),
                    "hdrs": clang_src_info.hdrs,
                    "module_name": target.c99name,
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

def _apple_static_xcframework_import_build_file(target):
    load_stmts = [apple_static_xcframework_import_load_stmt]
    glob = scg.new_fn_call(
        "glob",
        ["{tpath}/*.xcframework/**".format(tpath = target.path)],
    )
    decls = [
        build_decls.new(
            kind = apple_kinds.static_xcframework_import,
            name = pkginfo_targets.bazel_label_name(target),
            attrs = {
                "visibility": ["//visibility:public"],
                "xcframework_imports": glob,
            },
        ),
    ]
    return build_files.new(
        load_stmts = load_stmts,
        decls = decls,
    )

# MARK: - Apple Resource Group

def _apple_resource_bundle(repository_ctx, target, default_localization):
    bzl_target_name = pkginfo_targets.bazel_label_name(target)
    bundle_name = pkginfo_targets.resource_bundle_label_name(bzl_target_name)
    infoplist_name = pkginfo_targets.resource_bundle_infoplist_label_name(
        bzl_target_name,
    )

    glob_paths = []
    for r in target.resources:
        path = pkginfo_targets.join_path(target, r.path)
        if repository_files.is_directory(repository_ctx, path):
            glob_paths.append("{}/**".format(path))
        else:
            glob_paths.append(path)
    resources = scg.new_fn_call("glob", glob_paths)

    load_stmts = [
        apple_resource_bundle_load_stmt,
        swiftpkg_resource_bundle_infoplist_load_stmt,
        swiftpkg_resource_bundle_accessor_load_stmt,
    ]
    decls = [
        build_decls.new(
            kind = swiftpkg_kinds.resource_bundle_accessor,
            name = pkginfo_targets.resource_bundle_accessor_label_name(
                bzl_target_name,
            ),
            attrs = {
                "bundle_name": bundle_name,
            },
        ),
        build_decls.new(
            kind = swiftpkg_kinds.resource_bundle_infoplist,
            name = infoplist_name,
            attrs = {
                "region": default_localization,
            },
        ),
        build_decls.new(
            kind = apple_kinds.resource_bundle,
            name = bundle_name,
            attrs = {
                "bundle_name": bundle_name,
                "infoplists": [":{}".format(infoplist_name)],
                # Based upon the code in SPM, it looks like they only support unstructured resources.
                # https://github.com/apple/swift-package-manager/blob/main/Sources/PackageModel/Resource.swift#L25-L33
                "resources": resources,
            },
        ),
    ]
    return build_files.new(load_stmts = load_stmts, decls = decls)

# MARK: - Modulemap Generation

def _collect_modulemap_deps(deps):
    modulemap_deps = []
    for dep in deps:
        mm_values = [
            v
            for v in dep.value
            if pkginfo_targets.is_modulemap_label(v)
        ]
        if len(mm_values) == 0:
            continue
        mm_dep = bzl_selects.new(
            value = mm_values,
            kind = dep.kind,
            condition = dep.condition,
        )
        modulemap_deps.append(mm_dep)
    return modulemap_deps

def _generate_modulemap_for_swift_target(target, deps):
    load_stmts = [swiftpkg_generate_modulemap_load_stmt]
    bzl_target_name = pkginfo_targets.bazel_label_name(target)
    modulemap_target_name = pkginfo_targets.modulemap_label_name(bzl_target_name)
    modulemap_deps = _collect_modulemap_deps(deps)
    decls = [
        build_decls.new(
            kind = swiftpkg_kinds.generate_modulemap,
            name = modulemap_target_name,
            attrs = {
                "deps": bzl_selects.to_starlark(modulemap_deps),
                "hdrs": [":{}".format(bzl_target_name)],
                "module_name": target.c99name,
                "visibility": ["//visibility:public"],
            },
        ),
    ]
    return build_files.new(load_stmts = load_stmts, decls = decls)

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
    new_for_product = _new_for_product,
)

apple_kinds = struct(
    static_xcframework_import = "apple_static_xcframework_import",
    resource_bundle = "apple_resource_bundle",
)

apple_apple_location = "@build_bazel_rules_apple//apple:apple.bzl"

apple_resources_location = "@build_bazel_rules_apple//apple:resources.bzl"

apple_static_xcframework_import_load_stmt = load_statements.new(
    apple_apple_location,
    apple_kinds.static_xcframework_import,
)

apple_resource_bundle_load_stmt = load_statements.new(
    apple_resources_location,
    apple_kinds.resource_bundle,
)

swiftpkg_kinds = struct(
    generate_modulemap = "generate_modulemap",
    resource_bundle_accessor = "resource_bundle_accessor",
    resource_bundle_infoplist = "resource_bundle_infoplist",
)

swiftpkg_build_defs_location = "@rules_swift_package_manager//swiftpkg:build_defs.bzl"

swiftpkg_generate_modulemap_load_stmt = load_statements.new(
    swiftpkg_build_defs_location,
    swiftpkg_kinds.generate_modulemap,
)

swiftpkg_resource_bundle_accessor_load_stmt = load_statements.new(
    swiftpkg_build_defs_location,
    swiftpkg_kinds.resource_bundle_accessor,
)

swiftpkg_resource_bundle_infoplist_load_stmt = load_statements.new(
    swiftpkg_build_defs_location,
    swiftpkg_kinds.resource_bundle_infoplist,
)

_condition_kinds = struct(
    private_includes = "_privateIncludes",
    sdk_frameworks = "_sdkFrameworks",
    header_search_path = build_setting_kinds.header_search_path,
    linked_framework = build_setting_kinds.linked_framework,
    linked_library = build_setting_kinds.linked_library,
)
