"""Implementation for the `swift_worker_binary` rule."""

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_common")

def _swift_worker_binary_impl(ctx):
    tool_executable = ctx.executable.tool

    toolchain = swift_common.get_toolchain(ctx)
    swift_worker = toolchain.swift_worker

    extra_args_str = ""
    if ctx.attr.extra_args:
        extra_args_str = " " + " ".join([
            '"%s"' % a
            for a in ctx.attr.extra_args
        ])

    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = launcher,
        content = """\
#!/usr/bin/env bash
exec "{tool}" --swift_worker "{worker}"{extra_args} "$@"
""".format(
            tool = tool_executable.short_path,
            worker = swift_worker.executable.short_path,
            extra_args = extra_args_str,
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = ctx.files.data)
    runfiles = runfiles.merge(ctx.attr.tool[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(
        ctx.runfiles(files = [swift_worker.executable]),
    )

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
    },
    toolchains = swift_common.use_toolchain(),
)
