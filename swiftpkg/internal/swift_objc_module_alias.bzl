load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

def swift_objc_module_alias(name, deps, module_names, **kwargs):
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
