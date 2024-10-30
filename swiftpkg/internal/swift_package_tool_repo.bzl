"""Defines the `swift_package_tool_repo` repository rule that creates `swift_package_tool` targets."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:types.bzl", "types")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:swift_package_tool_attrs.bzl", "swift_package_tool_attrs")

def _package_config_attrs_to_content(attrs):
    """Returns a BUILD file compatible string representation of the keyword arguments"""
    kwargs = repository_utils.struct_to_kwargs(
        struct = attrs,
        keys = dicts.add(
            swift_package_tool_attrs.swift_package_tool_config,
            swift_package_tool_attrs.swift_package_registry,
        ),
    )

    kwarg_lines = []
    for k, v in kwargs.items():
        if types.is_string(v) or type(v) == "Label":
            kwarg_lines.append("    {key} = \"{value}\"".format(key = k, value = v))
        elif types.is_bool(v):
            kwarg_lines.append("    {key} = {value}".format(key = k, value = "True" if v else "False"))
        elif types.is_dict(v):
            json_str = json.encode(v)
            kwarg_lines.append("    {key} = {value}".format(key = k, value = json_str))
        else:
            fail("Unsupported value type for attribute {key}: {value}".format(key = k, value = v))

    return ",\n".join(kwarg_lines)

def _swift_package_tool_repo_impl(repository_ctx):
    attrs_content = _package_config_attrs_to_content(repository_ctx.attr)
    package_path = repository_ctx.attr.package

    repository_ctx.file(
        "BUILD.bazel",
        content = """
load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_package_tool")

swift_package_tool(
    name = "update",
    cmd = "update",
    package = "{package}",
{attrs_content}
)

swift_package_tool(
    name = "resolve",
    cmd = "resolve",
    package = "{package}",
{attrs_content}
)
""".format(
            package = package_path,
            attrs_content = attrs_content,
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
        swift_package_tool_attrs.swift_package_tool_config,
        swift_package_tool_attrs.swift_package_registry,
    ),
    doc = "Declares a `@swift_package` repository for using the `swift_package_tool` targets.",
)
