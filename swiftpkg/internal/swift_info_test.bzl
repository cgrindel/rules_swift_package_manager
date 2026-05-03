"""Defines the `swift_info_test` build-time check for the SPM cache."""

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_common")

def _swift_info_test_impl(ctx):
    toolchain = swift_common.get_toolchain(ctx)
    swift_worker = toolchain.swift_worker

    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        template = ctx.file._launcher_template,
        output = launcher,
        substitutions = {
            "{SWIFT_INFO}": ctx.file.swift_info.short_path,
            "{WORKER}": swift_worker.executable.short_path,
        },
        is_executable = True,
    )

    runfiles = ctx.runfiles(
        files = [ctx.file.swift_info, swift_worker.executable],
    )
    runfiles = runfiles.merge(
        ctx.attr._runfiles_lib[DefaultInfo].default_runfiles,
    )

    return [
        DefaultInfo(
            executable = launcher,
            files = depset([launcher]),
            runfiles = runfiles,
        ),
    ]

swift_info_test = rule(
    implementation = _swift_info_test_impl,
    doc = """\
Compares the cached Swift version recorded in `swift_info.json` against \
the version of the Swift toolchain Bazel resolves at build time. Fails \
the test when they disagree, prompting the user to refresh the SPM cache \
with `bazel run @swift_package//:cache -- --mode=update`.\
""",
    test = True,
    attrs = {
        "swift_info": attr.label(
            mandatory = True,
            allow_single_file = [".json"],
            doc = """\
The `swift_info.json` produced alongside the cache. Typically the \
`swift_info.json` from the directory passed via `--output_dir` to the \
`@swift_package//:cache` utility.\
""",
        ),
        "_launcher_template": attr.label(
            default = "@rules_swift_package_manager//swiftpkg/internal:swift_info_test_launcher.sh.tmpl",
            allow_single_file = True,
        ),
        "_runfiles_lib": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
    },
    toolchains = swift_common.use_toolchain(),
)
