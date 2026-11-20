"""Attributes shared between rules that interact with the Swift package tool."""

_swift_package_registry_attrs = {
    "netrc": attr.label(
        allow_single_file = True,
        doc = """
A `.netrc` file that contains authentication credentials used for fetching Swift packages and or binary artifacts.

When provided, this file will be passed to Swift Package Manager commands using \
the `--netrc-file` flag during package resolution and updates.
""",
    ),
    "registries": attr.label(
        allow_single_file = [".json"],
        doc = """
A `registries.json` file that defines the configured Swift package registries.

The `registries.json` file is used when resolving Swift packages from a \
Swift package registry. It is created by Swift Package Manager when using \
the `swift package-registry` commands.

When using the `swift_package_tool` rules, this file is symlinked to the \
`config_path` directory defined in the `configure_swift_package` tag. \
If not using the `swift_package_tool` rules, the file must be in one of \
Swift Package Manager's search paths or in the manually specified \
`--config-path` directory.
""",
    ),
}

_swift_package_tool_config_attrs = {
    "build_path": attr.string(
        doc = "The path for the Swift Package Manager build directory. A relative path is resolved against the workspace directory (`BUILD_WORKSPACE_DIRECTORY`).",
        default = ".build",
    ),
    "cache_path": attr.string(
        doc = "The path for the shared Swift Package Manager cache directory. A relative path is resolved against the workspace directory (`BUILD_WORKSPACE_DIRECTORY`).",
        default = ".cache",
    ),
    "config_path": attr.string(
        doc = "The path for the Swift Package Manager configuration directory. A relative path is resolved against the workspace directory (`BUILD_WORKSPACE_DIRECTORY`).",
        default = ".config",
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
    "replace_scm_with_registry": attr.bool(
        doc = """Look up source control dependencies in the registry and \
use the registry to retrieve them instead of source control when possible.""",
        default = False,
    ),
    "security_path": attr.string(
        doc = "The path for the security directory. A relative path is resolved against the workspace directory (`BUILD_WORKSPACE_DIRECTORY`).",
        default = ".security",
    ),
    "use_registry_identity_for_scm": attr.bool(
        doc = """Look up source control dependencies in the registry and use \
their registry identity when possible to help deduplicate across the two \
origins.
""",
        default = False,
    ),
}

swift_package_tool_attrs = struct(
    swift_package_registry = _swift_package_registry_attrs,
    swift_package_tool_config = _swift_package_tool_config_attrs,
)
