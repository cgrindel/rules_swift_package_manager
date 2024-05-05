"""Implementation for `swift_deps_index` rule."""

def _swift_deps_index_impl(ctx):
    out = ctx.actions.declare_file("{}.json".format(ctx.label.name))
    args = ctx.actions.args()
    args.add("create")
    for (idx, identity) in enumerate(ctx.attr.direct_dep_pkg_infos.values()):
        pi_file = ctx.files.direct_dep_pkg_infos[idx]
        args.add("{}={}".format(identity, pi_file.path))
    args.add_all(["-o", out])
    ctx.actions.run(
        outputs = [out],
        inputs = ctx.files.direct_dep_pkg_infos,
        executable = ctx.executable._swift_deps_index_tool,
        arguments = [args],
    )

    return [
        DefaultInfo(files = depset([out])),
    ]

swift_deps_index = rule(
    implementation = _swift_deps_index_impl,
    attrs = {
        "direct_dep_pkg_infos": attr.label_keyed_string_dict(
            allow_files = True,
            doc = """\
A `dict` where the key is the label for a Swift package's `pkg_info.json` file \
and the value is the Swift package's identity value.\
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
