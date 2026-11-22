"""Implementation for the `swift_deps_info_manifest` rule."""

def _swift_deps_info_manifest_impl(ctx):
    out = ctx.actions.declare_file("{}.json".format(ctx.label.name))
    pkg_info_paths = {}
    pkg_infos = []
    for target, identity in ctx.attr.direct_dep_pkg_infos.items():
        files = target.files.to_list()
        if len(files) != 1:
            fail("Expected one pkg_info.json file for {}, got {}.".format(
                identity,
                len(files),
            ))
        pkg_info_paths[identity] = files[0].path
        pkg_infos.append(files[0])
    ctx.actions.write(
        output = out,
        content = json.encode_indent({"direct_dep_pkg_infos": pkg_info_paths}),
    )
    pkg_infos_depset = depset(pkg_infos)
    return [
        DefaultInfo(files = depset([out], transitive = [pkg_infos_depset])),
        # Read by swift_gazelle_plugin's swift_deps_index rule.
        OutputGroupInfo(
            swift_deps_info_manifest = depset([out]),
            swift_deps_info_pkg_infos = pkg_infos_depset,
        ),
    ]

swift_deps_info_manifest = rule(
    implementation = _swift_deps_info_manifest_impl,
    attrs = {
        "direct_dep_pkg_infos": attr.label_keyed_string_dict(
            allow_files = True,
            doc = """\
A `dict` where the key is the label for a Swift package's `pkg_info.json` file \
and the value is the Swift package's identity value.\
""",
        ),
    },
    doc = """\
Writes a JSON manifest of the direct Swift package dependencies and their \
`pkg_info.json` files, for external tooling (e.g., the Swift Gazelle plugin's \
`swift_deps_index`).\
""",
)
