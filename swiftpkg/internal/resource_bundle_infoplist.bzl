"""Implementation for the `resource_bundle_infoplist` rule."""

# Inspired by
# https://github.com/apple/swift-package-manager/blob/main/Sources/Build/BuildPlan.swift#L1056-L1080

def _resource_bundle_infoplist_impl(ctx):
    out = ctx.actions.declare_file("{}_Info.plist".format(
        ctx.label.name,
    ))
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = out,
        substitutions = {
            "{DEV_REGION}": ctx.attr.region,
        },
    )
    return [DefaultInfo(files = depset([out]))]

resource_bundle_infoplist = rule(
    implementation = _resource_bundle_infoplist_impl,
    attrs = {
        "region": attr.string(
            # Not sure what a good default should be. A default localization or region is not
            # emitted in the dump or description JSON for a Swift package manifest.
            default = "en",
            doc = """\
The localization/region value that should be embedded in the Info.plist.\
""",
        ),
        "_template": attr.label(
            default = "@rules_swift_package_manager//swiftpkg/internal:resource_bundle_info.plist.tmpl",
            allow_single_file = True,
        ),
    },
    doc = "Generate an Info.plist for an SPM resource bundle.",
)
