"""Implementation for `generate_modulemap`."""

load(":module_maps.bzl", "write_module_map")

def _generate_modulemap_impl(ctx):
    module_name = ctx.attr.module_name
    out_filename = "{}.modulemap".format(module_name)
    out = ctx.actions.declare_file(out_filename)

    write_module_map(
        actions = ctx.actions,
        module_map_file = out,
        module_name = module_name,
        public_headers = ctx.files.public_hdrs,
    )

    files = depset([out] + ctx.files.public_hdrs)
    return DefaultInfo(files = files)

generate_modulemap = rule(
    implementation = _generate_modulemap_impl,
    attrs = {
        "module_name": attr.string(
            doc = "The name of the module.",
        ),
        "public_hdrs": attr.label_list(
            mandatory = True,
            allow_files = True,
            doc = "The public headers for this module.",
        ),
    },
    doc = "Generate a modulemap for an Objective-C module.",
)
