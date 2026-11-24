"""Implementation for the `swift_version_check` rule."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

# Positional arguments: $1 swift wrapper, $2 version file, $3 slice dir,
# $4 output marker. Paths are passed as arguments, never interpolated into the
# command.
_CHECK_COMMAND = """\
set -o errexit -o nounset -o pipefail
swift="$1"
version_file="$2"
slice_dir="$3"
out="$4"

want="$(cut -d. -f1,2 < "${version_file}")"
if ! version_output="$("${swift}" --version 2>&1)"; then
  printf 'swift_version_check: `swift --version` failed:\\n%s\\n' \
    "${version_output}" >&2
  exit 1
fi
have="$(printf '%s\\n' "${version_output}" \
  | sed -nE 's/.*Swift version ([0-9]+\\.[0-9]+).*/\\1/p' \
  | head -n 1)"
if [[ -z "${have}" ]]; then
  printf 'swift_version_check: could not parse `swift --version` output:\\n%s\\n' \
    "${version_output}" >&2
  exit 1
fi
if [[ "${have}" != "${want}" ]]; then
  printf '`swift_deps_cache` for slice `%s` was produced by Swift %s but this build uses Swift %s; run `bazel run @swift_package//:cache`\\n' \
    "${slice_dir}" "${want}" "${have}" >&2
  exit 1
fi
touch "${out}"
"""

def _swift_version_check_impl(ctx):
    validated = ctx.actions.declare_file("{}.validated".format(ctx.label.name))
    mode = ctx.attr._mode[BuildSettingInfo].value

    if mode == "off":
        ctx.actions.write(validated, "")
    else:
        ctx.actions.run_shell(
            inputs = [ctx.file.version_file],
            tools = [ctx.attr._swift[DefaultInfo].files_to_run],
            outputs = [validated],
            command = _CHECK_COMMAND,
            arguments = [
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
