"""Rule implementation for `resource_bundle_accessor`."""

def _resource_bundle_accessor_impl(ctx):
    out = ctx.actions.declare_file("{}_ResourceBundleAccessor.swift".format(
        ctx.label.name,
    ))
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = out,
        substitutions = {
            "{BUNDLE_NAME}": ctx.attr.bundle_name,
        },
    )
    return [DefaultInfo(files = depset([out]))]

resource_bundle_accessor = rule(
    implementation = _resource_bundle_accessor_impl,
    attrs = {
        "bundle_name": attr.string(
            mandatory = True,
            doc = "The name of the resource bundle.",
        ),
        "_template": attr.label(
            default = "@cgrindel_swift_bazel//swiftpkg/internal:ResourceBundleAccessor.swift.tmpl",
            allow_single_file = True,
        ),
    },
    doc = """\
Generate a Swift file with an SPM-specific `Bundle.module` accessor.\
""",
)
