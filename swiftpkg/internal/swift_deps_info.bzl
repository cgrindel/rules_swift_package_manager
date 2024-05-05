"""Implementation for `swift_deps_info` repository rule."""

def _swift_deps_info_impl(repository_ctx):
    direct_dep_pkg_infos = repository_ctx.attr.direct_dep_pkg_infos
    ddp_labels = "\n".join([
        "        \"{label}\": \"{identity}\",".format(
            label = ddpi,
            identity = direct_dep_pkg_infos[ddpi],
        )
        for ddpi in direct_dep_pkg_infos
    ])

    repository_ctx.file(
        "BUILD.bazel",
        executable = False,
        content = """
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_deps_index")

swift_deps_index(
    name = "swift_deps_index",
    direct_dep_pkg_infos = {{
{ddp_labels}
    }},
    visibility = ["//visibility:public"],
)
""".format(
            ddp_labels = ddp_labels,
        ),
    )

swift_deps_info = repository_rule(
    implementation = _swift_deps_info_impl,
    attrs = {
        # This must be a string_dict  for the labels to be written properly
        # when called from bzlmod/swift_deps.
        "direct_dep_pkg_infos": attr.string_dict(
            doc = """\
A `dict` where the key is the label for a Swift package's `pkg_info.json` file \
and the value is the Swift package's identity value.\
""",
        ),
    },
    doc = """\
Defines a repository that contains information about the Swift dependencies \
for a workspace.  It is used by other tooling (e.g., Swift Gazelle plugin).\
""",
)
