"""Implementation for `generate_modulemap`."""

load(":module_maps.bzl", "write_module_map")

ModuleMapInfo = provider(
    doc = "Contains information about a generate module map.",
    fields = {
        "module_name": "The name of the module.",
        "modulemap_file": "The module mape as a `File`.",
    },
)

def _generate_modulemap_impl(ctx):
    module_name = ctx.attr.module_name
    uses = [
        dep[ModuleMapInfo].module_name
        for dep in ctx.attr.deps
    ]
    out_filename = "{}/module.modulemap".format(module_name)
    modulemap_file = ctx.actions.declare_file(out_filename)

    write_module_map(
        actions = ctx.actions,
        module_map_file = modulemap_file,
        module_name = module_name,
        dependent_module_names = uses,
        public_headers = ctx.files.hdrs,
    )
    provider_hdr = [modulemap_file]

    return [
        DefaultInfo(files = depset([modulemap_file])),
        ModuleMapInfo(
            module_name = module_name,
            modulemap_file = modulemap_file,
        ),
        apple_common.new_objc_provider(
            module_map = depset([modulemap_file]),
        ),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                headers = depset(provider_hdr),
                includes = depset([modulemap_file.dirname]),
            ),
        ),
    ]

generate_modulemap = rule(
    implementation = _generate_modulemap_impl,
    attrs = {
        "deps": attr.label_list(
            providers = [ModuleMapInfo],
            doc = "The module maps that this module uses.",
        ),
        "hdrs": attr.label_list(
            mandatory = True,
            allow_files = True,
            doc = "The public headers for this module.",
        ),
        "module_name": attr.string(
            doc = "The name of the module.",
        ),
    },
    doc = "Generate a modulemap for an Objective-C module.",
)
