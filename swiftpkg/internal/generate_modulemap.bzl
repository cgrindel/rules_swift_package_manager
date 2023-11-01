"""Implementation for `generate_modulemap`."""

# The implementation of this rule was greatly inspired by the following:
# https://github.com/bazelbuild/rules_swift/blob/master/swift/internal/module_maps.bzl
# https://github.com/bazel-xcode/PodToBUILD/blob/e9bbf68151caf6c8cd9b8ed2fa361b38e0f6a860/BazelExtensions/extensions.bzl#L113
# https://github.com/bazel-xcode/xchammer/blob/master/sample/UrlGet/Vendor/rules_pods/BazelExtensions/extensions.bzl

load(":clang_files.bzl", "clang_files")
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

    # Decide whether we should generate the modulemap. If we do not generate
    # the modulemap, we still need to return expected providers.
    if ctx.attr.noop:
        return [
            DefaultInfo(files = depset([])),
            ModuleMapInfo(
                module_name = module_name,
                modulemap_file = None,
            ),
            apple_common.new_objc_provider(
                module_map = depset([]),
            ),
            CcInfo(
                compilation_context = cc_common.create_compilation_context(
                    headers = depset([]),
                    includes = depset([]),
                ),
            ),
        ]

    uses = [
        dep[ModuleMapInfo].module_name
        for dep in ctx.attr.deps
        if ModuleMapInfo in dep
    ]

    out_filename = "{}/module.modulemap".format(module_name)
    modulemap_file = ctx.actions.declare_file(out_filename)

    hdrs = [
        f
        for f in ctx.files.hdrs
        if clang_files.is_hdr(f.path)
    ]

    if len(hdrs) == 0:
        fail("No header files were provided.")

    write_module_map(
        actions = ctx.actions,
        module_map_file = modulemap_file,
        module_name = module_name,
        dependent_module_names = uses,
        public_headers = hdrs,
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
        "noop": attr.bool(
            doc = """\
Designates whether this should generate a modulemap. If `False`, a modulemap \
file is not generated and the returned providers are empty.\
""",
            default = False,
        ),
    },
    doc = "Generate a modulemap for an Objective-C module.",
)
