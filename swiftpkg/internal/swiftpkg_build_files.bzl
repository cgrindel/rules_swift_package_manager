"""Module for creating Bazel declarations to build a Swift package."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels", "lists")
load(":artifact_infos.bzl", "artifact_types", "link_types")
load(":bazel_apple_platforms.bzl", "bazel_apple_platforms")
load(":build_decls.bzl", "build_decls")
load(":build_files.bzl", "build_files")
load(":bzl_selects.bzl", "bzl_selects")
load(":load_statements.bzl", "load_statements")
load(":pkginfo_target_deps.bzl", "pkginfo_target_deps")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":pkginfos.bzl", "build_setting_kinds", "module_types", "pkginfos", "target_types")
load(":starlark_codegen.bzl", scg = "starlark_codegen")

_STRING_TYPE = type("")

# MARK: - Target Entry Point

def _new_for_target(repository_ctx, pkg_ctx, target, artifact_infos = []):
    if target.module_type == module_types.clang:
        return _clang_target_build_file(repository_ctx, pkg_ctx, target)
    elif target.module_type == module_types.swift:
        return _swift_target_build_file(pkg_ctx, target)
    elif target.module_type == module_types.system_library:
        return _system_library_build_file(target)
    elif target.module_type == module_types.binary:
        # GH558: Support artifactBundle.
        xcf_artifact_info = lists.find(
            artifact_infos,
            lambda ai: ai.artifiact_type == artifact_types.xcframework,
        )
        if xcf_artifact_info != None:
            return _xcframework_import_build_file(target, xcf_artifact_info)

    # GH046: Support plugins.
    return None

# MARK: - Swift Target

def _swift_target_build_file(pkg_ctx, target):
    if target.swift_src_info == None:
        fail("Expected a `swift_src_info`. name: ", target.name)

    all_build_files = []
    attrs = {
        "module_name": target.c99name,
        "srcs": pkginfo_targets.srcs(target),
        "visibility": ["//:__subpackages__"],
    }

    def _update_attr_list(name, value):
        # We need to create a new list, because the retrieved list could be
        # frozen.
        attr_list = list(attrs.get(name, []))
        attr_list.append(value)
        attrs[name] = attr_list

    # Naively parse the tools semver.
    tools_version = pkg_ctx.pkg_info.tools_version or "0.0.0"
    tools_version_components = tools_version.split(".") + ["0", "0"]
    tools_version_major, tools_version_minor = [int(x if x.isdigit() else "0") for x in tools_version_components[0:2]]

    # Gate package_name behind swift tools version 5.9
    if tools_version_major >= 6 or (tools_version_major == 5 and tools_version_minor >= 9):
        attrs["package_name"] = pkg_ctx.pkg_info.name

    target_deps = []
    macro_targets = []
    for target_dep in target.dependencies:
        dep_target_name = None
        if target_dep.target:
            dep_target_name = target_dep.target.target_name
        elif target_dep.by_name:
            dep_target_name = target_dep.by_name.name
        if not dep_target_name:
            target_deps.append(target_dep)
            continue
        dep_target = pkginfo_targets.get(
            targets = pkg_ctx.pkg_info.targets,
            name = dep_target_name,
            fail_if_not_found = False,
        )

        if not dep_target or dep_target.type != target_types.macro:
            target_deps.append(target_dep)
            continue
        macro_targets.append(dep_target)

    if macro_targets:
        attrs["plugins"] = [
            # The targets will be local to this repo. We do not want the '@'
            # prefix that can be added during normalization.
            bazel_labels.normalize(t.label).removeprefix("@")
            for t in macro_targets
        ]
    deps = []
    if target_deps:
        deps = lists.flatten([
            pkginfo_target_deps.bzl_select_list(pkg_ctx, td)
            for td in target_deps
        ])
        attrs["deps"] = bzl_selects.to_starlark(deps)

    # NOTE: We specify defines using copts so that they stay local to the
    # target. Specifying them using the defines attribute will propagate them.
    copts = [
        # SPM directive instructing the code to build as if a Swift package.
        # https://github.com/apple/swift-package-manager/blob/main/Documentation/Usage.md#packaging-legacy-code
        "-DSWIFT_PACKAGE",
    ]

    # GH046: Support plugins.

    is_library_target = lists.contains([target_types.library, target_types.regular], target.type)

    # Check if any of the sources indicate that the module will be used by
    # Objective-C code. If so, generate the bridge header file.
    if target.swift_src_info.has_objc_directive and is_library_target:
        attrs["generates_header"] = True

    if target.swift_settings != None:
        if len(target.swift_settings.defines) > 0:
            copts.extend(lists.flatten([
                bzl_selects.new_from_build_setting(
                    bs,
                    values_map_fn = lambda v: "-D" + v,
                )
                for bs in target.swift_settings.defines
            ]))
        if len(target.swift_settings.unsafe_flags) > 0:
            copts.extend(lists.flatten([
                bzl_selects.new_from_build_setting(bs)
                for bs in target.swift_settings.unsafe_flags
            ]))
        if len(target.swift_settings.experimental_features) > 0:
            for bs in target.swift_settings.experimental_features:
                copts.append("-enable-experimental-feature")
                copts.extend(lists.flatten(bzl_selects.new_from_build_setting(bs)))

    if len(copts) > 0:
        attrs["copts"] = bzl_selects.to_starlark(copts, mutually_inclusive = True)

    if target.resources:
        swift_apple_res_bundle_info = _apple_resource_bundle_for_swift(
            pkg_ctx,
            target,
        )
        all_build_files.append(swift_apple_res_bundle_info.build_file)
        _update_attr_list("data", ":{}".format(
            swift_apple_res_bundle_info.bundle_label_name,
        ))
        _update_attr_list("srcs", ":{}".format(
            swift_apple_res_bundle_info.accessor_label_name,
        ))

    if is_library_target:
        load_stmts = [swift_library_load_stmt]
        decls = [_swift_library_from_target(target, attrs)]
    elif target.type == target_types.executable:
        load_stmts = [swift_binary_load_stmt]
        decls = [_swift_binary_from_target(target, attrs)]
    elif target.type == target_types.test:
        load_stmts = [swift_test_load_stmt]
        decls = [_swift_test_from_target(target, attrs)]
    elif target.type == target_types.macro:
        load_stmts = [swift_compiler_plugin_load_stmt]
        decls = [_swift_compiler_plugin_from_target(target, attrs)]
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
    # Mark swift_library targets as manual. We do this so that they are always
    # built from a leaf node which can provide critical configuration
    # information.
    attrs["tags"] = ["manual"]

    # SPM always includes the developer search paths when compiling Swift
    # library targets. So, we do too.
    attrs["always_include_developer_search_paths"] = True

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

def _swift_compiler_plugin_from_target(target, attrs):
    # Macros are set up as compiler plugins. We expose macro products as an
    # alias to the swift_compiler_plugin target.
    attrs["visibility"] = ["//visibility:public"]
    return build_decls.new(
        kind = swift_kinds.compiler_plugin,
        name = pkginfo_targets.bazel_label_name(target),
        attrs = attrs,
    )

# MARK: - Clang Targets

def _c_child_library(
        repository_ctx,
        name,
        attrs,
        rule_kind,
        srcs,
        language_standard = None,
        res_copts = None):
    child_attrs = dicts.omit(attrs, ["data"])
    child_copts = list(attrs.get("copts", []))
    if res_copts:
        child_copts.extend(res_copts)
    child_attrs["srcs"] = lists.flatten([srcs, attrs.get("srcs", [])])
    if language_standard:
        child_copts.append("-std={}".format(language_standard))
    child_attrs["copts"] = child_copts
    return build_decls.new(
        rule_kind,
        name,
        attrs = _starlarkify_clang_attrs(repository_ctx, child_attrs),
    )

def _clang_target_build_file(repository_ctx, pkg_ctx, target):
    clang_src_info = target.clang_src_info
    if clang_src_info == None:
        fail("Expected `clang_src_info` to not be None.")
    all_build_files = []

    # These flags are used by SPM when compiling clang modules.
    copts = [
        # Enable 'blocks' language feature
        "-fblocks",
        # Synthesize retain and release calls for Objective-C pointers
        "-fobjc-arc",
        # Enable support for PIC macros
        "-fPIC",
        # The SWIFT_PACKAGE define is a magical value that SPM uses when it
        # builds clang libraries that will be used as Swift modules.
        "-DSWIFT_PACKAGE=1",
    ]

    # Do not add the srcs from the clang_src_info, yet. We will do that at the
    # end of this function where we will create separate targets based upon the
    # type of source file.
    srcs = []
    data = []
    deps = []

    res_copts = []
    clang_apple_res_bundle_info = None
    if target.resources:
        clang_apple_res_bundle_info = _apple_resource_bundle_for_clang(
            pkg_ctx,
            target,
        )
        all_build_files.append(clang_apple_res_bundle_info.build_file)
        data.append(":{}".format(
            clang_apple_res_bundle_info.bundle_label_name,
        ))
        if clang_apple_res_bundle_info.objc_accessor_hdr_label_name:
            srcs.extend([
                ":{}".format(
                    clang_apple_res_bundle_info.objc_accessor_hdr_label_name,
                ),
                # NOTE: We add the implementation as a dependency on a target
                # that compiles the implementation.
            ])
            deps.append(":" + clang_apple_res_bundle_info.objc_accessor_library_label_name)

            # SPM provides a SWIFTPM_MODULE_BUNDLE macro to access the bundle for
            # ObjC code.  The header file contains the macro definition. It needs
            # to be available in every Objc source file. So, we specify the
            # -include flag specifying the header path.
            # https://github.com/apple/swift-package-manager/blob/8387798811c6cc43761c5e1b48df2d3412dc5de4/Sources/Build/BuildDescription/ClangTargetBuildDescription.swift#L390
            res_copts.append("-include$(location :{})".format(
                clang_apple_res_bundle_info.objc_accessor_hdr_label_name,
            ))

    local_includes = [
        bzl_selects.new(value = p, kind = _condition_kinds.private_includes)
        for p in clang_src_info.private_includes
    ]

    def _normalize_and_create_copt_define(value):
        normalized = scg.normalize_define_value(value)
        return "-D" + normalized

    all_settings = lists.compact([target.clang_settings, target.cxx_settings])
    for settings in all_settings:
        copts.extend(lists.flatten([
            bzl_selects.new_from_build_setting(
                bs,
                # Define values can contain spaces. Bazel requires that they
                # are already escaped.
                values_map_fn = _normalize_and_create_copt_define,
            )
            for bs in settings.defines
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
            for bs in settings.hdr_srch_paths
        ]
        local_includes.extend(lists.flatten([
            bzl_selects.new_from_build_setting(bs)
            for bs in hsp_bss
        ]))

        copts.extend(lists.flatten([
            bzl_selects.new_from_build_setting(bs)
            for bs in settings.unsafe_flags
        ]))

    copts.extend(local_includes)

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

    # Assemble attributes

    attrs = {
        "copts": copts,
        "srcs": srcs,
        "visibility": ["//:__subpackages__"],
    }
    if clang_src_info.hdrs:
        attrs["hdrs"] = clang_src_info.hdrs
    if clang_src_info.public_includes:
        attrs["includes"] = clang_src_info.public_includes
    if clang_src_info.textual_hdrs:
        attrs["textual_hdrs"] = clang_src_info.textual_hdrs

    deps.extend(
        lists.flatten([
            pkginfo_target_deps.bzl_select_list(pkg_ctx, td)
            for td in target.dependencies
        ]),
    )
    if linkopts:
        attrs["linkopts"] = linkopts
    if deps:
        attrs["deps"] = deps
    if data:
        attrs["data"] = data

    # Generate cc_xxx and objc_xxx targets.

    bzl_target_name = target.label.name
    decls = []
    child_dep_names = []

    if target.objc_src_info != None:
        # Enable clang module support.
        # https://bazel.build/reference/be/objective-c#objc_library.enable_modules
        attrs["enable_modules"] = True

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
        if sdk_framework_bzl_selects:
            attrs["sdk_frameworks"] = sdk_framework_bzl_selects

        # There is a known issue with Objective-C library targets not
        # supporting the `@import` of modules defined in other Objective-C
        # targets. As a workaround, we will define two targets. One is the
        # `objc_library` target.  The other is a `generate_modulemap`
        # target. This second target generates a `module.modulemap` file and
        # provides information about that generated file to `objc_library`
        # targets, if `noop` is `False`. If `noop` is `True`, the target
        # generates nothing and returns "empty" providers.
        #
        # Why not skip adding the `generate_modulemap` if `noop` is `True`?
        # The logic that assigns dependencies for other targets has no way to
        # know whether the modulemap target exists. Hence, we ensure that it
        # always exists but does nothing.
        #
        # See `pkginfo_target_deps.bzl` for the logic that resolves the
        # dependency labels.
        # See `generate_modulemap.bzl` for details on the modulemap generation.
        # See `//swiftpkg/tests/generate_modulemap_tests` package for a usage
        # example.
        modulemap_deps = _collect_modulemap_deps(attrs.get("deps", []))
        load_stmts = [swiftpkg_generate_modulemap_load_stmt]
        modulemap_target_name = pkginfo_targets.modulemap_label_name(bzl_target_name)
        noop_modulemap = clang_src_info.modulemap_path != None
        modulemap_attrs = {
            "deps": bzl_selects.to_starlark(modulemap_deps),
            "hdrs": clang_src_info.hdrs,
            "module_name": target.c99name,
            "noop": noop_modulemap,
            "visibility": ["//:__subpackages__"],
        }
        decls.append(
            build_decls.new(
                kind = swiftpkg_kinds.generate_modulemap,
                name = modulemap_target_name,
                attrs = modulemap_attrs,
            ),
        )

        if clang_src_info.organized_srcs.objc_srcs:
            child_name = "{}_objc".format(bzl_target_name)
            child_dep_names.append(child_name)
            decls.append(
                _c_child_library(
                    repository_ctx,
                    name = child_name,
                    attrs = attrs,
                    rule_kind = objc_kinds.library,
                    srcs = clang_src_info.organized_srcs.c_srcs +
                           clang_src_info.organized_srcs.objc_srcs +
                           clang_src_info.organized_srcs.other_srcs,
                    language_standard = pkg_ctx.pkg_info.c_language_standard,
                    res_copts = res_copts,
                ),
            )
        if clang_src_info.organized_srcs.objcxx_srcs:
            child_name = "{}_objcxx".format(bzl_target_name)
            child_dep_names.append(child_name)
            decls.append(
                _c_child_library(
                    repository_ctx,
                    name = child_name,
                    attrs = attrs,
                    rule_kind = objc_kinds.library,
                    srcs = clang_src_info.organized_srcs.cxx_srcs +
                           clang_src_info.organized_srcs.objcxx_srcs +
                           clang_src_info.organized_srcs.other_srcs,
                    language_standard = pkg_ctx.pkg_info.cxx_language_standard,
                    res_copts = res_copts,
                ),
            )

        # Add the objc_library that brings all of the child targets together.
        uber_attrs = dicts.omit(attrs, ["srcs", "copts"]) | {
            "deps": [
                ":{}".format(dname)
                for dname in child_dep_names
            ],
        }
        uber_attrs["module_name"] = target.c99name
        decls.append(
            build_decls.new(
                objc_kinds.library,
                bzl_target_name,
                attrs = _starlarkify_clang_attrs(repository_ctx, uber_attrs),
            ),
        )

    else:
        aspect_hint_target_name = pkginfo_targets.swift_hint_label_name(
            bzl_target_name,
        )
        aspect_hint_attrs = {"module_name": target.c99name}

        load_stmts = [swift_interop_hint_load_stmt]
        decls.append(
            build_decls.new(
                kind = swift_kinds.interop_hint,
                name = aspect_hint_target_name,
                attrs = aspect_hint_attrs,
            ),
        )

        if clang_src_info.organized_srcs.c_srcs:
            child_name = "{}_c".format(bzl_target_name)
            child_dep_names.append(child_name)
            decls.append(
                _c_child_library(
                    repository_ctx,
                    name = child_name,
                    attrs = attrs,
                    rule_kind = clang_kinds.library,
                    srcs = clang_src_info.organized_srcs.c_srcs +
                           clang_src_info.organized_srcs.other_srcs,
                    language_standard = pkg_ctx.pkg_info.c_language_standard,
                ),
            )
        if clang_src_info.organized_srcs.cxx_srcs:
            child_name = "{}_cxx".format(bzl_target_name)
            child_dep_names.append(child_name)
            decls.append(
                _c_child_library(
                    repository_ctx,
                    name = child_name,
                    attrs = attrs,
                    rule_kind = clang_kinds.library,
                    srcs = clang_src_info.organized_srcs.cxx_srcs +
                           clang_src_info.organized_srcs.other_srcs,
                    language_standard = pkg_ctx.pkg_info.cxx_language_standard,
                ),
            )

        if clang_src_info.organized_srcs.assembly_srcs:
            child_name = "{}_assembly".format(bzl_target_name)
            child_dep_names.append(child_name)
            decls.append(
                _c_child_library(
                    repository_ctx,
                    name = child_name,
                    attrs = attrs,
                    rule_kind = clang_kinds.library,
                    srcs = clang_src_info.organized_srcs.assembly_srcs +
                           clang_src_info.organized_srcs.other_srcs,
                ),
            )

        # Add the cc_library that brings all of the child targets together.
        uber_attrs = dicts.omit(attrs, ["srcs", "copts"]) | {
            "aspect_hints": [":{}".format(aspect_hint_target_name)],
            "deps": [
                ":{}".format(dname)
                for dname in child_dep_names
            ],
        }
        decls.append(
            build_decls.new(
                clang_kinds.library,
                bzl_target_name,
                attrs = _starlarkify_clang_attrs(repository_ctx, uber_attrs),
            ),
        )

    all_build_files.append(build_files.new(
        load_stmts = load_stmts,
        decls = decls,
    ))

    return build_files.merge(*all_build_files)

def _starlarkify_clang_attrs(repository_ctx, attrs):
    attrs = dict(**attrs)

    deps = attrs.get("deps")
    if deps:
        attrs["deps"] = bzl_selects.to_starlark(deps)

    # Short path relative to Bazel output base. This is typically used when
    # adding a path to a copt or linkeropt.
    ext_repo_path = paths.join("external", repository_ctx.name)

    # The `includes` attribute adds includes as -isystem which propagates
    # to cc_XXX that depend upon the library.  Providing includes as -I
    # only provides the includes for this target.
    # https://bazel.build/reference/be/c-cpp#cc_library.includes
    def _local_includes_transform(p):
        # Normalize the path and replace spaces with an escape sequence.
        normalized = paths.normalize(paths.join(ext_repo_path, p))
        normalized = normalized.replace(" ", "\\ ")
        return "-I{}".format(normalized)

    copts = attrs.get("copts")
    if copts:
        attrs["copts"] = bzl_selects.to_starlark(
            copts,
            kind_handlers = {
                _condition_kinds.header_search_path: bzl_selects.new_kind_handler(
                    transform = _local_includes_transform,
                ),
                _condition_kinds.private_includes: bzl_selects.new_kind_handler(
                    transform = _local_includes_transform,
                ),
            },
        )

    linkopts = attrs.get("linkopts")
    if linkopts:
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

    sdk_frameworks = attrs.get("sdk_frameworks")
    if sdk_frameworks:
        attrs["sdk_frameworks"] = bzl_selects.to_starlark(
            sdk_frameworks,
        )

    return attrs

# MARK: - System Library Targets

# GH009(chuck): Remove unused-variable directives

# buildifier: disable=unused-variable
def _system_library_build_file(target):
    # GH009(chuck): Implement _system_library_build_file
    return None

# MARK: - Apple xcframework Targets

def _xcframework_import_build_file(target, artifact_info):
    attrs = {}
    if artifact_info.link_type == link_types.static:
        load_stmts = [apple_static_xcframework_import_load_stmt]
        kind = apple_kinds.static_xcframework_import

        # Firebase example requires that GoogleAppMeasurement symbols are
        # passed along.
        attrs["alwayslink"] = True
    elif artifact_info.link_type == link_types.dynamic:
        load_stmts = [apple_dynamic_xcframework_import_load_stmt]
        kind = apple_kinds.dynamic_xcframework_import
    else:
        fail(
            """\
Unexpected link type for target. target: {target}, link_type: {link_type}, \
expected: {expected}\
""".format(
                target = target.name,
                link_type = artifact_info.link_type,
                expected = ", ".join([link_types.static, link_types.dynamic]),
            ),
        )
    if target.path.endswith(".xcframework"):
        glob = scg.new_fn_call(
            "glob",
            ["{tpath}/**".format(tpath = target.path)],
        )
    else:
        glob = scg.new_fn_call(
            "glob",
            ["{tpath}/*.xcframework/**".format(tpath = target.path)],
        )
    decls = [
        build_decls.new(
            kind = kind,
            name = pkginfo_targets.bazel_label_name(target),
            attrs = attrs | {
                "visibility": ["//:__subpackages__"],
                "xcframework_imports": glob,
            },
        ),
    ]
    return build_files.new(
        load_stmts = load_stmts,
        decls = decls,
    )

# MARK: - Apple Resource Group

def _apple_resource_bundle(target, package_name, default_localization):
    bzl_target_name = pkginfo_targets.bazel_label_name(target)
    bundle_label_name = pkginfo_targets.resource_bundle_label_name(bzl_target_name)
    bundle_name = pkginfo_targets.resource_bundle_name(package_name, target.c99name)
    infoplist_name = pkginfo_targets.resource_bundle_infoplist_label_name(
        bzl_target_name,
    )

    resources = sorted([
        r.path
        for r in target.resources
    ])

    load_stmts = [
        apple_resource_bundle_load_stmt,
        swiftpkg_resource_bundle_infoplist_load_stmt,
    ]
    decls = [
        build_decls.new(
            kind = swiftpkg_kinds.resource_bundle_infoplist,
            name = infoplist_name,
            attrs = {
                "region": default_localization,
            },
        ),
        build_decls.new(
            kind = apple_kinds.resource_bundle,
            name = bundle_label_name,
            attrs = {
                "bundle_name": bundle_name,
                "infoplists": [":{}".format(infoplist_name)],
                # Based upon the code in SPM, it looks like they only support unstructured resources.
                # https://github.com/apple/swift-package-manager/blob/main/Sources/PackageModel/Resource.swift#L25-L33
                "resources": resources,
                "visibility": ["//:__subpackages__"],
            },
        ),
    ]
    return struct(
        bundle_name = bundle_name,
        bundle_label_name = bundle_label_name,
        build_file = build_files.new(load_stmts = load_stmts, decls = decls),
    )

def _apple_resource_bundle_for_swift(pkg_ctx, target):
    apple_res_bundle_info = _apple_resource_bundle(
        target,
        pkg_ctx.pkg_info.name,
        pkg_ctx.pkg_info.default_localization,
    )

    # Apparently, SPM provides a `Bundle.module` accessor. So, we do too.
    # https://stackoverflow.com/questions/63237395/generating-resource-bundle-accessor-type-bundle-has-no-member-module
    accessor_label_name = pkginfo_targets.resource_bundle_accessor_label_name(
        pkginfo_targets.bazel_label_name(target),
    )
    return struct(
        bundle_label_name = apple_res_bundle_info.bundle_label_name,
        accessor_label_name = accessor_label_name,
        build_file = build_files.merge(
            apple_res_bundle_info.build_file,
            build_files.new(
                load_stmts = [swiftpkg_resource_bundle_accessor_load_stmt],
                decls = [
                    build_decls.new(
                        kind = swiftpkg_kinds.resource_bundle_accessor,
                        name = accessor_label_name,
                        attrs = {
                            "bundle_name": apple_res_bundle_info.bundle_name,
                        },
                    ),
                ],
            ),
        ),
    )

def _apple_resource_bundle_for_clang(pkg_ctx, target):
    apple_res_bundle_info = _apple_resource_bundle(
        target,
        pkg_ctx.pkg_info.name,
        pkg_ctx.pkg_info.default_localization,
    )
    all_build_files = [apple_res_bundle_info.build_file]
    objc_accessor_hdr_label_name = None
    objc_accessor_impl_label_name = None
    objc_accessor_library_label_name = None
    if target.objc_src_info:
        bzl_target_name = pkginfo_targets.bazel_label_name(target)
        objc_accessor_hdr_label_name = pkginfo_targets.objc_resource_bundle_accessor_hdr_label_name(
            bzl_target_name,
        )
        objc_accessor_impl_label_name = pkginfo_targets.objc_resource_bundle_accessor_impl_label_name(
            bzl_target_name,
        )
        objc_accessor_library_label_name = pkginfo_targets.objc_resource_bundle_accessor_library_label_name(
            bzl_target_name,
        )
        all_build_files.append(
            build_files.new(
                load_stmts = [
                    swiftpkg_objc_resource_bundle_accessor_hdr_load_stmt,
                    swiftpkg_objc_resource_bundle_accessor_impl_load_stmt,
                ],
                decls = [
                    build_decls.new(
                        kind = swiftpkg_kinds.objc_resource_bundle_accessor_hdr,
                        name = objc_accessor_hdr_label_name,
                        attrs = {
                            "module_name": target.c99name,
                        },
                    ),
                    build_decls.new(
                        kind = swiftpkg_kinds.objc_resource_bundle_accessor_impl,
                        name = objc_accessor_impl_label_name,
                        attrs = {
                            "bundle_name": apple_res_bundle_info.bundle_name,
                            "extension": "m",
                            "module_name": target.c99name,
                        },
                    ),
                    build_decls.new(
                        kind = objc_kinds.library,
                        name = objc_accessor_library_label_name,
                        attrs = {
                            "hdrs": [":" + objc_accessor_hdr_label_name],
                            "srcs": [":" + objc_accessor_impl_label_name],
                        },
                    ),
                ],
            ),
        )
    return struct(
        bundle_label_name = apple_res_bundle_info.bundle_label_name,
        objc_accessor_hdr_label_name = objc_accessor_hdr_label_name,
        objc_accessor_library_label_name = objc_accessor_library_label_name,
        build_file = build_files.merge(*all_build_files),
    )

# MARK: - Modulemap Generation

def _collect_modulemap_deps(deps):
    modulemap_deps = []
    for dep in deps:
        if type(dep) == _STRING_TYPE:
            continue
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
    attrs = {
        "deps": bzl_selects.to_starlark(modulemap_deps),
        "hdrs": [":{}".format(bzl_target_name)],
        "module_name": target.c99name,
        "visibility": ["//:__subpackages__"],
    }
    decls = [
        build_decls.new(
            kind = swiftpkg_kinds.generate_modulemap,
            name = modulemap_target_name,
            attrs = attrs,
        ),
    ]
    return build_files.new(load_stmts = load_stmts, decls = decls)

# MARK: - Products Entry Point

def _new_for_products(pkg_ctx):
    bld_files = lists.compact([
        _new_for_product(pkg_ctx, prod)
        for prod in pkg_ctx.pkg_info.products
    ])

    # If we did not generate any build files, return an empty one.
    if len(bld_files) == 0:
        return build_files.new()
    return build_files.merge(*bld_files)

def _new_for_product(pkg_ctx, product):
    prod_type = product.type
    if prod_type.is_executable:
        return _executable_product_build_file(
            pkg_ctx.pkg_info,
            product,
            pkg_ctx.repo_name,
        )
    elif prod_type.is_library:
        return _library_product_build_file(pkg_ctx, product)
    elif prod_type.is_macro:
        return _alias_for_macro_build_file(pkg_ctx, product)

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

def _library_product_build_file(pkg_ctx, product):
    # A library product can reference one or more Swift targets. Hence a
    # dependency on a library product is a shorthand for depend upon all of the
    # Swift targets that is associated with the product. We use a
    # `swift_library_group` to represent this.
    target_labels = []
    for tname in product.targets:
        target = lists.find(pkg_ctx.pkg_info.targets, lambda t: t.name == tname)
        if target == None:
            fail("Did not find a target named {}.".format(tname))
        target_labels.extend(
            pkginfo_target_deps.labels_for_target(pkg_ctx.repo_name, target),
        )

    if len(target_labels) == 0:
        fail("No targets specified for a library product. name:", product.name)
    return build_files.new(
        load_stmts = [swift_library_group_load_stmt],
        decls = [
            build_decls.new(
                swift_kinds.library_group,
                product.name,
                attrs = {
                    "deps": [
                        bazel_labels.normalize(label)
                        for label in target_labels
                    ],
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

def _alias_for_macro_build_file(pkg_ctx, product):
    if len(product.targets) != 1:
        fail("""\
Expected only one target for the macro product {name} but received {count}.\
""".format(
            name = product.name,
            count = len(product.targets),
        ))
    target = pkginfo_targets.get(pkg_ctx.pkg_info.targets, product.targets[0])
    label_name = pkginfo_targets.bazel_label_name(target)
    return build_files.new(
        decls = [
            build_decls.new(
                native_kinds.alias,
                product.name,
                attrs = {
                    "actual": ":{}".format(label_name),
                    "visibility": ["//visibility:public"],
                },
            ),
        ],
    )

# MARK: - License

def _new_for_license(pkg_info, license):
    packageinfo_target_name = "package_info.rspm"
    decls = [
        build_decls.new(
            rules_license_kinds.package_info,
            packageinfo_target_name,
            attrs = {
                "package_name": pkg_info.name,
                "package_url": pkg_info.url,
                "package_version": pkg_info.version,
            },
        ),
    ]
    default_package_metadata = [":{}".format(packageinfo_target_name)]
    load_stmts = [rules_license_package_info_load_stmt]

    if license:
        license_target_name = "license.rspm"
        decls.append(
            build_decls.new(
                rules_license_kinds.license,
                license_target_name,
                attrs = {
                    "license_text": license,
                },
            ),
        )
        load_stmts.append(rules_license_license_load_stmt)
        default_package_metadata.insert(0, ":{}".format(license_target_name))

    return build_files.new(
        load_stmts = load_stmts,
        package_attrs = {"default_package_metadata": default_package_metadata},
        decls = decls,
    )

# MARK: - Constants and API Definition

swift_location = "@build_bazel_rules_swift//swift:swift.bzl"

swift_kinds = struct(
    library = "swift_library",
    library_group = "swift_library_group",
    binary = "swift_binary",
    test = "swift_test",
    c_module = "swift_c_module",
    compiler_plugin = "swift_compiler_plugin",
    interop_hint = "swift_interop_hint",
)

swift_library_load_stmt = load_statements.new(
    swift_location,
    swift_kinds.library,
)

swift_library_group_load_stmt = load_statements.new(
    swift_location,
    swift_kinds.library_group,
)

swift_binary_load_stmt = load_statements.new(
    swift_location,
    swift_kinds.binary,
)

swift_c_module_load_stmt = load_statements.new(
    swift_location,
    swift_kinds.c_module,
)

swift_compiler_plugin_load_stmt = load_statements.new(
    swift_location,
    swift_kinds.compiler_plugin,
)

swift_interop_hint_load_stmt = load_statements.new(
    swift_location,
    swift_kinds.interop_hint,
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

rules_license_license_location = "@rules_license//rules:license.bzl"
rules_license_package_info_location = "@rules_license//rules:package_info.bzl"

rules_license_kinds = struct(
    license = "license",
    package_info = "package_info",
)

rules_license_license_load_stmt = load_statements.new(
    rules_license_license_location,
    rules_license_kinds.license,
)

rules_license_package_info_load_stmt = load_statements.new(
    rules_license_package_info_location,
    rules_license_kinds.package_info,
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
    new_for_license = _new_for_license,
    new_for_target = _new_for_target,
    new_for_products = _new_for_products,
    new_for_product = _new_for_product,
)

apple_kinds = struct(
    static_xcframework_import = "apple_static_xcframework_import",
    dynamic_xcframework_import = "apple_dynamic_xcframework_import",
    resource_bundle = "apple_resource_bundle",
)

apple_apple_location = "@build_bazel_rules_apple//apple:apple.bzl"

apple_resources_location = "@build_bazel_rules_apple//apple:resources.bzl"

apple_static_xcframework_import_load_stmt = load_statements.new(
    apple_apple_location,
    apple_kinds.static_xcframework_import,
)

apple_dynamic_xcframework_import_load_stmt = load_statements.new(
    apple_apple_location,
    apple_kinds.dynamic_xcframework_import,
)

apple_resource_bundle_load_stmt = load_statements.new(
    apple_resources_location,
    apple_kinds.resource_bundle,
)

swiftpkg_kinds = struct(
    generate_modulemap = "generate_modulemap",
    objc_resource_bundle_accessor_hdr = "objc_resource_bundle_accessor_hdr",
    objc_resource_bundle_accessor_impl = "objc_resource_bundle_accessor_impl",
    resource_bundle_accessor = "resource_bundle_accessor",
    resource_bundle_infoplist = "resource_bundle_infoplist",
)

swiftpkg_build_defs_location = "@rules_swift_package_manager//swiftpkg:build_defs.bzl"

swiftpkg_generate_modulemap_load_stmt = load_statements.new(
    swiftpkg_build_defs_location,
    swiftpkg_kinds.generate_modulemap,
)

swiftpkg_objc_resource_bundle_accessor_hdr_load_stmt = load_statements.new(
    swiftpkg_build_defs_location,
    swiftpkg_kinds.objc_resource_bundle_accessor_hdr,
)

swiftpkg_objc_resource_bundle_accessor_impl_load_stmt = load_statements.new(
    swiftpkg_build_defs_location,
    swiftpkg_kinds.objc_resource_bundle_accessor_impl,
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
