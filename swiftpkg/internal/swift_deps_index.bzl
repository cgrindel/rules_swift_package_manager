"""Implementation for `swift_deps_index` rule."""

def _swift_deps_index_impl(ctx):
    out = ctx.actions.declare_file("{}.json".format(ctx.label.name))
    direct_dep_pkg_infos = ctx.files.direct_dep_pkg_infos

    args = ctx.actions.args()
    args.add("create")
    args.add_all(direct_dep_pkg_infos)
    args.add_all(["-o", out])
    ctx.actions.run(
        outputs = [out],
        inputs = direct_dep_pkg_infos,
        executable = ctx.executable._swift_deps_index_tool,
        arguments = [args],
    )

    return [
        DefaultInfo(files = depset([out])),
    ]

swift_deps_index = rule(
    implementation = _swift_deps_index_impl,
    attrs = {
        "direct_dep_pkg_infos": attr.label_list(
            allow_files = True,
            doc = """\
The `pkg_info.json` files for the direct dependencies.
""",
        ),
        "_swift_deps_index_tool": attr.label(
            executable = True,
            cfg = "exec",
            default = "//tools/swift_deps_index",
        ),
    },
    doc = """\
Generates a Swift dependencies index file that is used by other tooling (e.g., \
Swift Gazelle plugin).\
""",
)
