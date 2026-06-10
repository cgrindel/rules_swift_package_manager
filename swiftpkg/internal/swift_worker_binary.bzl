"""Implementation for the `swift_worker_binary` rule."""

def _swift_worker_binary_impl(ctx):
    tool_executable = ctx.executable.tool

    # Write extra_args to a params file (one arg per line) so the
    # launcher can read them at runtime without Starlark-side shell
    # escaping. ctx.expand_location must still happen in Starlark —
    # Args does not perform $(rootpath ...) substitution itself.
    expanded = [
        ctx.expand_location(a, targets = ctx.attr.data)
        for a in ctx.attr.extra_args
    ]
    args_obj = ctx.actions.args()
    args_obj.add_all(expanded)

    # Default "shell" format wraps args-with-whitespace in single quotes,
    # which would then be read back into the array as literal quotes. Use
    # "multiline" so every arg is written verbatim, one per line.
    args_obj.set_param_file_format("multiline")
    args_file = ctx.actions.declare_file(ctx.label.name + ".args")
    ctx.actions.write(output = args_file, content = args_obj)

    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        template = ctx.file._launcher_template,
        output = launcher,
        substitutions = {
            "{ARGS_FILE}": args_file.short_path,
            "{TOOL}": tool_executable.short_path,
        },
        is_executable = True,
    )

    # Include ctx.files.data for direct file labels (plain files have no
    # rule and thus empty default_runfiles), plus merge each dep's
    # default_runfiles to pick up transitive runfiles from rule targets.
    runfiles = ctx.runfiles(
        files = ctx.files.data + [args_file],
    )
    runfiles = runfiles.merge(ctx.attr.tool[DefaultInfo].default_runfiles)
    for dep in ctx.attr.data:
        runfiles = runfiles.merge(dep[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(
            executable = launcher,
            files = depset([launcher]),
            runfiles = runfiles,
        ),
    ]

swift_worker_binary = rule(
    implementation = _swift_worker_binary_impl,
    doc = """\
A reusable rule that generates a launcher script wrapping a provided tool \
executable. Baked-in extra_args are passed before any user-provided \
command-line arguments.\
""",
    executable = True,
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            doc = "Additional data files available at runtime.",
        ),
        "extra_args": attr.string_list(
            doc = """\
Additional arguments baked into the launcher script, passed before any \
user-provided command-line arguments.\
""",
        ),
        "tool": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "The executable to run, followed by any user-provided args.",
        ),
        "_launcher_template": attr.label(
            default = "@rules_swift_package_manager//swiftpkg/internal:swift_worker_binary_launcher.sh.tmpl",
            allow_single_file = True,
        ),
    },
)
