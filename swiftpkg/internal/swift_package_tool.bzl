"""Implementation for the `swift_package_tool` rule used by the `swift_deps` bzlmod extension."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_common")
load(
    "//swiftpkg/internal:swift_package_tool_attrs.bzl",
    "swift_package_tool_attrs",
)

def _swift_package_tool_impl(ctx):
    build_path = ctx.attr.build_path
    cache_path = ctx.attr.cache_path
    config_path = ctx.attr.config_path
    cmd = ctx.attr.cmd
    package = ctx.attr.package
    package_path = paths.dirname(package)
    registries = ctx.file.registries
    runfiles = []

    toolchain = swift_common.get_toolchain(ctx)
    swift = toolchain.swift_worker
    runfiles.append(swift.executable)

    if registries:
        runfiles.append(registries)

    runner_script = ctx.actions.declare_file(ctx.label.name + ".sh")
    template_dict = ctx.actions.template_dict()
    template_dict.add("%(swift_worker)s", swift.executable.short_path)
    template_dict.add("%(cmd)s", cmd)
    template_dict.add("%(package_path)s", package_path)
    template_dict.add("%(build_path)s", build_path)
    template_dict.add("%(cache_path)s", cache_path)
    template_dict.add("%(config_path)s", config_path)
    template_dict.add(
        "%(enable_build_manifest_caching)s",
        "true" if ctx.attr.manifest_caching else "false",
    )
    template_dict.add(
        "%(enable_dependency_cache)s",
        "true" if ctx.attr.dependency_caching else "false",
    )
    template_dict.add("%(manifest_cache)s", ctx.attr.manifest_cache)
    template_dict.add(
        "%(registries_json)s",
        registries.short_path if registries else "",
    )
    template_dict.add(
        "%(replace_scm_with_registry)s",
        "true" if ctx.attr.replace_scm_with_registry else "false",
    )
    template_dict.add("%(security_path)s", ctx.attr.security_path)
    template_dict.add(
        "%(use_registry_identity_for_scm)s",
        "true" if ctx.attr.use_registry_identity_for_scm else "false",
    )

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
            runfiles = ctx.runfiles(files = runfiles),
        ),
    ]

swift_package_tool = rule(
    implementation = _swift_package_tool_impl,
    doc = """\
Defines a rule that can be used to execute the `swift package` tool.\
""",
    attrs = dicts.add(
        swift_common.toolchain_attrs(),
        {
            "cmd": attr.string(
                doc = "The `swift package` command to execute.",
                mandatory = True,
                values = ["update", "resolve"],
            ),
            "package": attr.string(
                doc = """\
The relative path to the `Package.swift` file from the workspace root.\
""",
                mandatory = True,
            ),
            "_runner_template": attr.label(
                doc = "The template for the runner script.",
                allow_single_file = True,
                default = Label(
                    "//swiftpkg/internal:swift_package_tool_runner_template.sh",
                ),
            ),
        },
        swift_package_tool_attrs.swift_package_tool_config,
        swift_package_tool_attrs.swift_package_registry,
    ),
    executable = True,
)
