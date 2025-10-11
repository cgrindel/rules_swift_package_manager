"""Defines the `swift_package_tool_repo` repository rule that creates `swift_package_tool` targets."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:types.bzl", "types")
load("//swiftpkg/internal:repo_rules.bzl", "repo_rules")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:swift_package_tool_attrs.bzl", "swift_package_tool_attrs")

def _package_config_attrs_to_content(attrs):
    """Returns a BUILD file compatible string representation of the keyword arguments"""
    kwargs = repository_utils.struct_to_kwargs(
        struct = attrs,
        keys = dicts.add(
            repo_rules.env_attr,
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

    # We copy .netrc file contents to avoid requiring users to use `exports_files(...)`
    netrc_attr = None
    if repository_ctx.attr.netrc:
        netrc_content = repository_ctx.read(repository_ctx.attr.netrc)
        repository_ctx.file(".netrc", netrc_content)
        netrc_attr = '    netrc = ":.netrc",'

    attrs_lines = [line for line in attrs_content.split("\n") if "netrc =" not in line]
    filtered_attrs = "\n".join(attrs_lines)

    final_attrs_parts = [filtered_attrs]
    if netrc_attr:
        final_attrs_parts.append(netrc_attr)
    final_attrs_content = "\n".join([p for p in final_attrs_parts if p])

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
            attrs_content = final_attrs_content,
        ),
    )

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

# Exported for testing
swift_package_tool_repo_testing = struct(
    package_config_attrs_to_content = _package_config_attrs_to_content,
)
