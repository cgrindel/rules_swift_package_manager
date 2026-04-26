"""Implementation for the `swift_worker_binary` rule."""

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_common")

def _swift_worker_binary_impl(ctx):
    tool_executable = ctx.executable.tool

    toolchain = swift_common.get_toolchain(ctx)
    swift_worker = toolchain.swift_worker

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
            "{WORKER}": swift_worker.executable.short_path,
        },
        is_executable = True,
    )

    # Include ctx.files.data for direct file labels (plain files have no
    # rule and thus empty default_runfiles), plus merge each dep's
    # default_runfiles to pick up transitive runfiles from rule targets.
    runfiles = ctx.runfiles(
        files = ctx.files.data + [args_file, swift_worker.executable],
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
A reusable rule that resolves the Swift toolchain and generates a launcher \
script. It wraps a provided tool executable, passing `--swift_worker <path>` \
as the first arguments so the tool can locate and use the Bazel-configured \
Swift toolchain.\
""",
    executable = True,
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            doc = "Additional data files available at runtime.",
        ),
        "extra_args": attr.string_list(
            doc = """\
Additional arguments baked into the launcher script after --swift_worker. \
These are passed before any user-provided command-line arguments.\
""",
        ),
        "tool": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = """\
The executable to run. The launcher passes --swift_worker <path> as the \
first args, followed by any user-provided args.\
""",
        ),
        "_launcher_template": attr.label(
            default = "@rules_swift_package_manager//swiftpkg/internal:swift_worker_binary_launcher.sh.tmpl",
            allow_single_file = True,
        ),
    },
    toolchains = swift_common.use_toolchain(),
)
