"""Implementation for the `swift_package_tool` rule used by the `swift_deps` bzlmod extension."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_common")

# The name of the runner script.
_RUNNER_SCRIPT_NAME = "swift_package.sh"

def _swift_package_tool_impl(ctx):
    build_path = ctx.attr.build_path
    cache_path = ctx.attr.cache_path
    cmd = ctx.attr.cmd
    package = ctx.attr.package
    package_path = paths.dirname(package)

    toolchain = swift_common.get_toolchain(ctx)
    swift = toolchain.swift_worker

    runner_script = ctx.actions.declare_file(_RUNNER_SCRIPT_NAME)
    template_dict = ctx.actions.template_dict()
    template_dict.add("%(swift_worker)s", swift.executable.short_path)
    template_dict.add("%(cmd)s", cmd)
    template_dict.add("%(package_path)s", package_path)
    template_dict.add("%(build_path)s", build_path)
    template_dict.add("%(cache_path)s", cache_path)
    template_dict.add("%(enable_build_manifest_caching)s", "true" if ctx.attr.manifest_caching else "false")
    template_dict.add("%(enable_dependency_cache)s", "true" if ctx.attr.dependency_caching else "false")
    template_dict.add("%(manifest_cache)s", ctx.attr.manifest_cache)

    ctx.actions.expand_template(
        template = ctx.file._runner_template,
        is_executable = True,
        output = runner_script,
        computed_substitutions = template_dict,
    )

    return [
        DefaultInfo(
            executable = runner_script,
            files = depset([runner_script]),
            runfiles = ctx.runfiles(files = [swift.executable]),
        ),
    ]

SWIFT_PACKAGE_CONFIG_ATTRS = {
    "build_path": attr.string(
        doc = "The relative path within the runfiles tree for the Swift Package Manager build directory.",
        default = ".build",
    ),
    "cache_path": attr.string(
        doc = "The relative path within the runfiles tree for the shared Swift Package Manager cache directory.",
        default = ".cache",
    ),
    "dependency_caching": attr.bool(
        doc = "Whether to enable the dependency cache.",
        default = True,
    ),
    "manifest_cache": attr.string(
        doc = """Caching mode of Package.swift manifests \
(shared: shared cache, local: package's build directory, none: disabled)
""",
        default = "shared",
        values = ["shared", "local", "none"],
    ),
    "manifest_caching": attr.bool(
        doc = "Whether to enable build manifest caching.",
        default = True,
    ),
}

swift_package_tool = rule(
    implementation = _swift_package_tool_impl,
    doc = "Defines a rule that can be used to execute the `swift package` tool.",
    attrs = dicts.add(
        swift_common.toolchain_attrs(),
        {
            "cmd": attr.string(
                doc = "The `swift package` command to execute.",
                mandatory = True,
                values = ["update", "resolve"],
            ),
            "package": attr.string(
                doc = "The relative path to the `Package.swift` file from the workspace root.",
                mandatory = True,
            ),
            "_runner_template": attr.label(
                doc = "The template for the runner script.",
                allow_single_file = True,
                default = Label("//swiftpkg/internal:swift_package_tool_runner_template.sh"),
            ),
        },
        SWIFT_PACKAGE_CONFIG_ATTRS,
    ),
    executable = True,
)
