"""Rule implementation for `objc_resource_bundle_accessor`."""

# def _objc_resource_bundle_accessor_impl(ctx):
#     accessor_impl = ctx.actions.declare_file("{}_ObjcResourceBundleAccessor.m".format(
#         ctx.label.name,
#     ))
#     accessor_hdr = ctx.actions.declare_file("{}_ObjcResourceBundleAccessor.h".format(
#         ctx.label.name,
#     ))
#     cc_info = ctx.attr.bundle[CcInfo]

#     # DEBUG BEGIN
#     print("*** CHUCK cc_info: ", cc_info)
#     print("*** CHUCK cc_info.linking_context.linker_inputs: ", cc_info.linking_context.linker_inputs)

#     # DEBUG END
#     ctx.actions.expand_template(
#         template = ctx.file._impl_template,
#         output = accessor_impl,
#         substitutions = {
#             "{BUNDLE_NAME}": ctx.attr.bundle_name,
#             # TODO(chuck): FIX ME!
#             # "{BUNDLE_PATH}": ctx.file.bundle.path,
#             "{MODULE_NAME}": ctx.attr.module_name,
#         },
#     )
#     ctx.actions.expand_template(
#         template = ctx.file._hdr_template,
#         output = accessor_hdr,
#         substitutions = {
#             "{MODULE_NAME}": ctx.attr.module_name,
#         },
#     )
#     return [DefaultInfo(files = depset([accessor_impl, accessor_hdr]))]

# objc_resource_bundle_accessor = rule(
#     implementation = _objc_resource_bundle_accessor_impl,
#     attrs = {
#         "bundle": attr.label(
#             mandatory = True,
#             doc = "The name of the module.",
#             providers = [[CcInfo]],
#         ),
#         "bundle_name": attr.string(
#             mandatory = True,
#             doc = "The name of the resource bundle.",
#         ),
#         "module_name": attr.string(
#             mandatory = True,
#             doc = "The name of the module.",
#         ),
#         "_hdr_template": attr.label(
#             default = "@rules_swift_package_manager//swiftpkg/internal:ObjcResourceBundleAccessor.h.tmpl",
#             allow_single_file = True,
#         ),
#         "_impl_template": attr.label(
#             default = "@rules_swift_package_manager//swiftpkg/internal:ObjcResourceBundleAccessor.m.tmpl",
#             allow_single_file = True,
#         ),
#     },
#     doc = """\
# Generate an ObjC file with an SPM-specific `SWIFTPM_MODULE_BUNDLE` macro.\
# """,
# )

def _objc_resource_bundle_accessor_hdr_impl(ctx):
    accessor_hdr = ctx.actions.declare_file("{}_ObjcResourceBundleAccessor.h".format(
        ctx.label.name,
    ))
    ctx.actions.expand_template(
        template = ctx.file._hdr_template,
        output = accessor_hdr,
        substitutions = {
            "{MODULE_NAME}": ctx.attr.module_name,
        },
    )
    return [DefaultInfo(files = depset([accessor_hdr]))]

objc_resource_bundle_accessor_hdr = rule(
    implementation = _objc_resource_bundle_accessor_hdr_impl,
    attrs = {
        "module_name": attr.string(
            mandatory = True,
            doc = "The name of the module.",
        ),
        "_hdr_template": attr.label(
            default = "@rules_swift_package_manager//swiftpkg/internal:ObjcResourceBundleAccessor.h.tmpl",
            allow_single_file = True,
        ),
    },
    doc = """\
Generate an ObjC header file with an SPM-specific `SWIFTPM_MODULE_BUNDLE` macro.\
""",
)

def _objc_resource_bundle_accessor_impl_impl(ctx):
    accessor_impl = ctx.actions.declare_file("{}_ObjcResourceBundleAccessor.m".format(
        ctx.label.name,
    ))
    ctx.actions.expand_template(
        template = ctx.file._impl_template,
        output = accessor_impl,
        substitutions = {
            "{BUNDLE_NAME}": ctx.attr.bundle_name,
            "{HDR_NAME}": ctx.file.hdr.basename,
            # TODO(chuck): FIX ME!
            # "{BUNDLE_PATH}": ctx.file.bundle.path,
            "{MODULE_NAME}": ctx.attr.module_name,
        },
    )
    return [DefaultInfo(files = depset([accessor_impl]))]

objc_resource_bundle_accessor_impl = rule(
    implementation = _objc_resource_bundle_accessor_impl_impl,
    attrs = {
        "bundle": attr.label(
            mandatory = True,
            doc = "The name of the module.",
            providers = [[CcInfo]],
        ),
        "bundle_name": attr.string(
            mandatory = True,
            doc = "The name of the resource bundle.",
        ),
        "hdr": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "module_name": attr.string(
            mandatory = True,
            doc = "The name of the module.",
        ),
        "_impl_template": attr.label(
            default = "@rules_swift_package_manager//swiftpkg/internal:ObjcResourceBundleAccessor.m.tmpl",
            allow_single_file = True,
        ),
    },
    doc = """\
Generate an ObjC implementation file with an SPM-specific `SWIFTPM_MODULE_BUNDLE` macro implementation.\
""",
)
