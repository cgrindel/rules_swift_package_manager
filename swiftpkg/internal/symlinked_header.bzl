"""Implementation for the `symlinked_header` rule."""

load("@bazel_skylib//lib:paths.bzl", "paths")

def _symlinked_header_impl(ctx):
    out = ctx.actions.declare_symlink(ctx.attr.out)

    # Relative to the symlink's directory: back up to the execution root, then
    # down to the target's exec path. It resolves wherever the action runs.
    up = "/".join([".."] * len(out.dirname.split("/")))
    ctx.actions.symlink(
        output = out,
        target_path = paths.join(up, ctx.file.target.path),
    )
    return [DefaultInfo(files = depset([out]))]

symlinked_header = rule(
    implementation = _symlinked_header_impl,
    attrs = {
        "out": attr.string(
            mandatory = True,
            doc = "The symlink's path relative to the package.",
        ),
        "target": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The header that the symlink points to.",
        ),
    },
    doc = """\
Recreates a header symlink from a Swift package as a symlink that Bazel \
declares, so that remote executors receive a symlink instead of a copy.\
""",
)
