"""Implementation for `swift_package`."""

def _swift_package_impl(ctx):
    pass

swift_package = repository_rule(
    implementation = _swift_package_impl,
    attrs = {
        "commit": attr.string(
            mandatory = True,
            doc = "The commit or revision to download from version control.",
        ),
        "remote": attr.string(
            mandatory = True,
            doc = """\
The version control location from where the repository should be downloaded.\
""",
        ),
    },
    doc = "",
)
