"""Implementation for the `swift_package_stale` rule."""

def _swift_package_stale_impl(ctx):
    fail(ctx.attr.message)

swift_package_stale = rule(
    implementation = _swift_package_stale_impl,
    attrs = {
        "message": attr.string(
            doc = "The failure message to report at analysis time.",
            mandatory = True,
        ),
    },
    doc = """\
Fails at analysis time with `message`.

Generated `select()` branches for stale cache slices point at this rule so \
that only builds that select a stale slice fail.\
""",
)
