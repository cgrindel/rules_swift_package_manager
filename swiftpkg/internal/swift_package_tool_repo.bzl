"""Defines the `swift_package_tool_repo` repository rule that creates `swift_package_tool` targets."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:build_files.bzl", "build_files")
load("//swiftpkg/internal:load_statements.bzl", "load_statements")
load("//swiftpkg/internal:repo_rules.bzl", "repo_rules")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:swift_package_tool_attrs.bzl", "swift_package_tool_attrs")

_attr_keys = dicts.add(
    repo_rules.env_attr,
    swift_package_tool_attrs.swift_package_tool_config,
    swift_package_tool_attrs.swift_package_registry,
)

def _collect_tool_attrs(repository_ctx):
    """Collects the swift_package_tool attributes from the repository context.

    Args:
        repository_ctx: A `repository_ctx` instance.

    Returns:
        A `dict` of attribute key-value pairs for swift_package_tool targets.
    """
    kwargs = repository_utils.struct_to_kwargs(
        struct = repository_ctx.attr,
        keys = _attr_keys,
    )

    # Convert Label values to strings so starlark_codegen can handle them.
    for k, v in kwargs.items():
        if type(v) == "Label":
            kwargs[k] = str(v)

    # We copy .netrc file contents to avoid requiring users to use
    # `exports_files(...)`
    if repository_ctx.attr.netrc:
        netrc_content = repository_ctx.read(repository_ctx.attr.netrc)
        repository_ctx.file(".netrc", netrc_content)
        kwargs["netrc"] = ":.netrc"

    return kwargs

def _swift_package_tool_repo_impl(repository_ctx):
    package_path = repository_ctx.attr.package
    tool_attrs = _collect_tool_attrs(repository_ctx)

    common_attrs = dict(tool_attrs)
    common_attrs["package"] = package_path

    bld_file = build_files.new(
        load_stmts = [
            load_statements.new(
                "@rules_swift_package_manager//swiftpkg:defs.bzl",
                "swift_package_tool",
            ),
        ],
        decls = [
            build_decls.new(
                "swift_package_tool",
                name = "update",
                attrs = dicts.add(common_attrs, {"cmd": "update"}),
            ),
            build_decls.new(
                "swift_package_tool",
                name = "resolve",
                attrs = dicts.add(common_attrs, {"cmd": "resolve"}),
            ),
        ],
    )
    build_files.write(repository_ctx, bld_file, "")

swift_package_tool_repo = repository_rule(
    implementation = _swift_package_tool_repo_impl,
    attrs = dicts.add(
        repo_rules.env_attr,
        {
            "package": attr.string(
                doc = "The relative path to the `Package.swift` file to operate on.",
                mandatory = True,
            ),
        },
        swift_package_tool_attrs.swift_package_tool_config,
        swift_package_tool_attrs.swift_package_registry,
    ),
    doc = "Declares a `@swift_package` repository for using the `swift_package_tool` targets.",
)
