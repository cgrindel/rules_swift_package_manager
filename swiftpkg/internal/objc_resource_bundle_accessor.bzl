"""Rule implementation for `objc_resource_bundle_accessor`."""

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
    accessor_impl = ctx.actions.declare_file(
        "{label}_ObjcResourceBundleAccessor.{ext}".format(
            ext = ctx.attr.extension,
            label = ctx.label.name,
        ),
    )
    ctx.actions.expand_template(
        template = ctx.file._impl_template,
        output = accessor_impl,
        substitutions = {
            "{BUNDLE_NAME}": ctx.attr.bundle_name,
            "{BUNDLE_PATH}": ctx.attr.bundle_name + ".bundle",
            "{MODULE_NAME}": ctx.attr.module_name,
        },
    )
    return [DefaultInfo(files = depset([accessor_impl]))]

objc_resource_bundle_accessor_impl = rule(
    implementation = _objc_resource_bundle_accessor_impl_impl,
    attrs = {
        "bundle_name": attr.string(
            mandatory = True,
            doc = "The name of the resource bundle.",
        ),
        "extension": attr.string(
            default = "m",
            doc = "The extension for the accessor implementation file.",
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
