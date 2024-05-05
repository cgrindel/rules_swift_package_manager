"""Implementation for `swift_deps_info` repository rule."""

def _swift_deps_info_impl(repository_ctx):
    ddp_labels = "\n".join([
        "        \"{}\",".format(ddpi)
        for ddpi in repository_ctx.attr.direct_dep_pkg_infos
    ])
    repository_ctx.file(
        "BUILD.bazel",
        executable = False,
        content = """
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_deps_index")

swift_deps_index(
    name = "swift_deps_index",
    direct_dep_pkg_infos = [
{ddp_labels}
    ],
    visibility = ["//visibility:public"],
)
""".format(
            ddp_labels = ddp_labels,
        ),
    )

# TODO(chuck): Remove direct_dep_repo_names and replace with
# direct_dep_pkg_infos. This will take labels to pkg_info.json for each direct
# dependency.  The repo rule will combine the pkg_info to a JSON list and write
# to a file.

swift_deps_info = repository_rule(
    implementation = _swift_deps_info_impl,
    attrs = {
        # This must be a string_list, not a label_list for the labels to be
        # written properly when called from bzlmod/swift_deps.
        "direct_dep_pkg_infos": attr.string_list(
            doc = """\
The `pkg_info.json` files for the direct dependencies.
""",
        ),
    },
    doc = """\
Defines a repository that contains information about the Swift dependencies \
for a workspace.  It is used by other tooling (e.g., Swift Gazelle plugin).\
""",
)
