"""Defines the `swift_package_tool_repo` repository rule that creates `swift_package_tool` targets."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:swift_package_tool.bzl", "SWIFT_PACKAGE_CONFIG_ATTRS")

def _swift_package_tool_repo_impl(repository_ctx):
    package_path = repository_ctx.attr.package

    # Construct the list of keyword arguments for the `swift_package_tool` rule.
    # String should be "key = \"value\""
    # NOTE: only supports string typed values as they are all quoted
    kwargs = repository_utils.struct_to_kwargs(
        struct = repository_ctx.attr,
        keys = SWIFT_PACKAGE_CONFIG_ATTRS,
    )
    kwarg_content = ",\n".join([
        "    {key} = \"{value}\"".format(key = k, value = v)
        for k, v in kwargs.items()
    ])

    repository_ctx.file(
        "BUILD.bazel",
        content = """
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_package_tool")

swift_package_tool(
    name = "update",
    cmd = "update",
    package = "{package}",
{kwarg_content}
)

swift_package_tool(
    name = "resolve",
    cmd = "resolve",
    package = "{package}",
{kwarg_content}
)
""".format(
            package = package_path,
            kwarg_content = kwarg_content,
        ),
    )

swift_package_tool_repo = repository_rule(
    implementation = _swift_package_tool_repo_impl,
    attrs = dicts.add(
        {
            "package": attr.string(
                doc = "The relative path to the `Package.swift` file to operate on.",
                mandatory = True,
            ),
        },
        SWIFT_PACKAGE_CONFIG_ATTRS,
    ),
    doc = "Declares a `@swift_package` repository for using the `swift_package_tool` targets.",
)
