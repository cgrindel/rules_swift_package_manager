"""Implementation for the `swift_version_check` rule."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _swift_version_check_impl(ctx):
    validated = ctx.actions.declare_file("{}.validated".format(ctx.label.name))
    mode = ctx.attr._mode[BuildSettingInfo].value

    if mode == "off":
        ctx.actions.write(validated, "")
    else:
        # The script is a source file, so run it through `bash` rather than
        # rely on its executable bit. Paths are passed as arguments, never
        # interpolated into the command.
        ctx.actions.run_shell(
            inputs = [ctx.file.version_file, ctx.file._script],
            tools = [ctx.attr._swift[DefaultInfo].files_to_run],
            outputs = [validated],
            command = 'exec bash "${@}"',
            arguments = [
                ctx.file._script.path,
                ctx.executable._swift.path,
                ctx.file.version_file.path,
                ctx.attr.slice_dir,
                validated.path,
            ],
            mnemonic = "SwiftVersionCheck",
            progress_message = "Checking Swift version for slice {}".format(
                ctx.attr.slice_dir,
            ),
            use_default_shell_env = True,
        )

    return [
        DefaultInfo(files = depset()),
        OutputGroupInfo(_validation = depset([validated])),
    ]

swift_version_check = rule(
    implementation = _swift_version_check_impl,
    attrs = {
        "slice_dir": attr.string(
            mandatory = True,
            doc = "The slice directory, used in the failure message.",
        ),
        "version_file": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The cache's `swift_version.txt` (`major.minor.patch`).",
        ),
        "_mode": attr.label(
            default = Label("//:swift_version_check"),
        ),
        "_script": attr.label(
            allow_single_file = True,
            default = Label(":swift_version_check.sh"),
        ),
        "_swift": attr.label(
            default = Label("//tools:swift"),
            cfg = "exec",
            executable = True,
        ),
    },
    doc = """\
Validates that the resolved Swift toolchain's `major.minor` version matches \
the version that produced a slice's `swift_deps_cache`. The check runs as a \
`_validation` output. `--@rules_swift_package_manager//:swift_version_check=off` \
skips it.\
""",
)
