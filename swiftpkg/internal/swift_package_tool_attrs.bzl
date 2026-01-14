"""Attributes shared between rules that interact with the Swift package tool."""

_swift_package_registry_attrs = {
    "replace_scm_with_registry": attr.bool(
        doc = """When enabled replaces SCM identities in dependencies package description \
with identities from the registries.

Using this option requires that the registries provide `repositoryURLs` as \
metadata for the package.

When `True` the equivalent `--replace-scm-with-registry` option must be used \
with the Swift Package Manager CLI (or `swift_package` rule) so that the \
`resolved` file includes the version and identity information from the registry.

For more information see the \
[Swift Package Manager documentation](https://github.com/swiftlang/swift-package-manager/blob/swift-6.0.1-RELEASE/Documentation/PackageRegistry/Registry.md#45-lookup-package-identifiers-registered-for-a-url).""",
        default = False,
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
    "use_registry_identity_for_scm": attr.bool(
        doc = """Look up source control dependencies in the registry and use \
their registry identity when possible to help deduplicate across the two \
origins.
""",
        default = False,
    ),
}

_swift_package_tool_config_attrs = {
    "build_path": attr.string(
        doc = "The relative path within the runfiles tree for the Swift Package Manager build directory.",
        default = ".build",
    ),
    "cache_path": attr.string(
        doc = "The relative path within the runfiles tree for the shared Swift Package Manager cache directory.",
        default = ".cache",
    ),
    "config_path": attr.string(
        doc = "The relative path within the runfiles tree for the Swift Package Manager configuration directory.",
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
    "security_path": attr.string(
        doc = "The relative path within the runfiles tree for the security directory.",
        default = ".security",
    ),
}

swift_package_tool_attrs = struct(
    swift_package_registry = _swift_package_registry_attrs,
    swift_package_tool_config = _swift_package_tool_config_attrs,
)
