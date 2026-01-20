"""Implementation for `swift_dev_deps` bzlmod extension."""

load("//swiftpkg/internal:repo_rules.bzl", "repo_rules")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:swift_package_tool_attrs.bzl", "swift_package_tool_attrs")
load("//swiftpkg/internal:swift_package_tool_repo.bzl", "swift_package_tool_repo")

# MARK: - swift_dev_deps bzlmod Extension

def _declare_swift_package_repo(
        *,
        module_ctx,
        from_package,
        name):
    # Find the configure tag for this repo.
    config_swift_package = None
    for mod in module_ctx.modules:
        for config_swift_package_tag in mod.tags.configure_swift_package:
            if config_swift_package:
                fail("""\
Expected only one `configure_swift_package` tag, but found multiple.\
""")
            config_swift_package = config_swift_package_tag

    # Collect attrs forwarded to the repository rule.
    from_package_kwargs = repository_utils.struct_to_kwargs(
        struct = from_package,
        keys = swift_package_tool_attrs.swift_package_registry,
    )
    config_swift_package_kwargs = repository_utils.struct_to_kwargs(
        struct = config_swift_package,
        keys = swift_package_tool_attrs.swift_package_tool_config,
    )

    # Resolve the env and env_inherit attributes.
    resolved_env = {}
    if from_package:
        for key in from_package.env:
            resolved_env[key] = from_package.env[key]
        for key in from_package.env_inherit:
            value = module_ctx.getenv(key, None)
            if value != None:
                resolved_env[key] = value

    swift_package_tool_repo(
        name = name,
        env = resolved_env,
        package = "{package}/{name}".format(
            package = from_package.swift.package,
            name = from_package.swift.name,
        ),
        **(from_package_kwargs | config_swift_package_kwargs)
    )

def _swift_dev_deps_impl(module_ctx):
    if not module_ctx.is_dev_dependency:
        fail("""\
`swift_dev_deps` must be marked as `dev_dependency = True` in a `use_extension` declaration.
""")

    # Find the from_package tag.
    from_package = None
    for mod in module_ctx.modules:
        for from_package_tag in mod.tags.from_package:
            if from_package:
                fail("""\
Expected only one `from_package` tag, but found multiple.\
""")
            from_package = from_package_tag

    direct_dev_repo_names = []
    declare_swift_package = True

    if from_package:
        declare_swift_package = from_package.declare_swift_package

    # Declare the `swift_package` repository which can be used to execute SPM commands.
    if declare_swift_package:
        swift_package_repo_name = "swift_package"
        _declare_swift_package_repo(
            module_ctx = module_ctx,
            name = swift_package_repo_name,
            from_package = from_package,
        )
        direct_dev_repo_names.append(swift_package_repo_name)

    return module_ctx.extension_metadata(
        root_module_direct_deps = [],
        root_module_direct_dev_deps = direct_dev_repo_names,
    )

_from_package_tag = tag_class(
    attrs = repo_rules.env_attrs |
            swift_package_tool_attrs.swift_package_registry | {
        "declare_swift_package": attr.bool(
            default = True,
            doc = """\
Declare a `swift_package_tool` repository named `swift_package` which defines two targets:
`update` and `resolve`.\

These targets run can be used to run the `swift package` binary in a Bazel context.
The flags used when running the underlying `swift package` can be configured \
using the `configure_swift_package` tag.

They can be `bazel run` to update/resolve the `resolved` file:

```
bazel run @swift_package//:update
bazel run @swift_package//:resolve
```
""",
        ),
        "swift": attr.label(
            mandatory = True,
            allow_files = [".swift"],
            doc = "A `Package.swift`.",
        ),
    },
    doc = "Used to configure the `swift_deps_info` repository.",
)

_configure_swift_package_tag = tag_class(
    attrs = swift_package_tool_attrs.swift_package_tool_config,
    doc = "Used to configure the flags used when running the `swift package` binary.",
)

swift_dev_deps = module_extension(
    implementation = _swift_dev_deps_impl,
    tag_classes = {
        "configure_swift_package": _configure_swift_package_tag,
        "from_package": _from_package_tag,
    },
)
