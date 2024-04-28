"""Implementation for `swift_deps_index` rule."""

def _swift_deps_index_impl(ctx):
    # TODO(chuck): Need to call a tool that generates the swift index.
    pass

swift_deps_index = rule(
    implementation = _swift_deps_index_impl,
    attrs = {
        "direct_dep_pkg_infos": attr.label_list(
            allow_files = True,
            doc = """\
The `pkg_info.json` files for the direct dependencies.
""",
        ),
    },
    doc = """\
Generates a Swift dependencies index file that is used by other tooling (e.g., \
Swift Gazelle plugin).\
""",
)
