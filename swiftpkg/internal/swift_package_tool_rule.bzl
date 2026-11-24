"""Implementation for the `swift_package_tool_rule` rule."""

def _swift_package_tool_rule_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(
        output = out,
        target_file = ctx.executable._tool,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = ctx.files.data + [ctx.executable._swift])
    runfiles = runfiles.merge_all(
        [
            ctx.attr._tool[DefaultInfo].default_runfiles,
            ctx.attr._swift[DefaultInfo].default_runfiles,
        ] + [d[DefaultInfo].default_runfiles for d in ctx.attr.data],
    )

    swift_tool = ctx.expand_location(
        "$(rlocationpath {})".format(ctx.attr._swift.label),
        targets = [ctx.attr._swift],
    )
    return [
        DefaultInfo(executable = out, runfiles = runfiles),
        RunEnvironmentInfo(environment = {"RSPM_SWIFT_TOOL": swift_tool}),
    ]

swift_package_tool_rule = rule(
    implementation = _swift_package_tool_rule_impl,
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            doc = """\
Files that the tool reads at run time, such as the patch files referenced \
with `$(rootpath ...)` in `args`.\
""",
        ),
        "_swift": attr.label(
            default = Label("//tools:swift"),
            cfg = "exec",
            executable = True,
        ),
        "_tool": attr.label(
            default = Label("//tools/swift_deps_tool"),
            cfg = "exec",
            executable = True,
        ),
    },
    doc = """\
Runs `swift_deps_tool` with the `swift` wrapper from the Swift toolchain.

The generated `@swift_package` repository sets `args` to the tool command and \
its flags, as rendered by `swift_package_tool_args.render`. The rule passes \
the `swift` wrapper's runfiles path to the tool in the `RSPM_SWIFT_TOOL` \
environment variable.\
""",
    executable = True,
)
