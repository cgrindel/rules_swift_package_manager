"""Defines the `swift_objc_module_alias` macro."""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

def swift_objc_module_alias(name, deps, module_names, **kwargs):
    """Defines a Swift module that exports the named modules from the specified \
    dependencies.

    This macro is useful for working around a known issue with Objective-C
    library targets not supporting the `@import` of modules defined in other
    Objective-C targets. It works because `swift_library` knows how to access
    modules defined in an Objective-C library and Swift has an undocumented
    feature for re-exporting modules defined in a dependent module.

    Caution: This macro generates a Swift source file that relies on the
    undocumented `@_exported` feature to re-export the listed modules.

    Args:
        name: The name of the `swift_library` that is generated. (`string`)
        deps: A `list` of targets that provide the listed modules.
        module_names: A `list` of the module names (`string` values) that
            should be re-exported.
        **kwargs: Attributes that are passed along to the `swift_library`
            declaration.
    """
    swift_src_name = name + "SwiftSrc"
    write_file(
        name = swift_src_name,
        out = "{}.swift".format(swift_src_name),
        content = [
            "@_exported import {}".format(mn)
            for mn in module_names
        ],
    )

    swift_library(
        name = name,
        srcs = [swift_src_name],
        deps = deps,
        **kwargs
    )
