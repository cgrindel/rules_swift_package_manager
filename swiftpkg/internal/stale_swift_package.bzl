"""Implementation for the `stale_swift_package` repository rule."""

def _stale_swift_package_impl(repository_ctx):
    fail(repository_ctx.attr.message)

stale_swift_package = repository_rule(
    implementation = _stale_swift_package_impl,
    attrs = {
        "message": attr.string(
            doc = "The failure message to report at fetch time.",
            mandatory = True,
        ),
    },
    doc = """\
Fails at fetch time with `message`.

Declared for a package identity that only stale cache slices know about. It \
needs a workspace to run, so it is covered by the integration tests rather \
than unit tests.\
""",
)
