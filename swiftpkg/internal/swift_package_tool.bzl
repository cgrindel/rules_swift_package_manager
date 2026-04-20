"""Macro that wraps `swift_worker_binary` to provide backward-compatible `swift_package_tool` targets."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//swiftpkg/internal:manifest_swiftc_args.bzl", "manifest_swiftc_args")
load("//swiftpkg/internal:swift_worker_binary.bzl", "swift_worker_binary")

def _manifest_swiftc_flags():
    return " ".join(manifest_swiftc_args.BAZEL_DEFINE)

def _bool_str(value):
    return "true" if value else "false"

def swift_package_tool(
        name,
        cmd,
        package,
        build_path = ".build",
        cache_path = ".cache",
        config_path = ".config",
        security_path = ".security",
        manifest_caching = True,
        dependency_caching = True,
        manifest_cache = "shared",
        replace_scm_with_registry = False,
        use_registry_identity_for_scm = False,
        netrc = None,
        registries = None,
        env = None,
        **kwargs):
    """Creates a `swift_worker_binary` target that runs `swift package <cmd>`.

    This macro preserves the `swift_package_tool` API while delegating to
    `swift_worker_binary` and the `swift_package_cmd` tool script.

    Args:
        name: The target name.
        cmd: The `swift package` command to execute ("update" or "resolve").
        package: Relative path to the `Package.swift` file from the workspace root.
        build_path: Relative path for the SPM build directory.
        cache_path: Relative path for the shared SPM cache directory.
        config_path: Relative path for the SPM configuration directory.
        security_path: Relative path for the security directory.
        manifest_caching: Whether to enable build manifest caching.
        dependency_caching: Whether to enable the dependency cache.
        manifest_cache: Caching mode of Package.swift manifests (shared, local, none).
        replace_scm_with_registry: Look up source control deps in the registry.
        use_registry_identity_for_scm: Use registry identity for source control deps.
        netrc: Label for a `.netrc` authentication file.
        registries: Label for a `registries.json` file.
        env: Dict of environment variables to pass through.
        **kwargs: Additional keyword arguments passed to `swift_worker_binary`.
    """
    package_path = paths.dirname(package)

    extra_args = [
        "--cmd",
        cmd,
        "--package_path",
        package_path,
        "--build_path",
        build_path,
        "--cache_path",
        cache_path,
        "--config_path",
        config_path,
        "--security_path",
        security_path,
        "--enable_build_manifest_caching",
        _bool_str(manifest_caching),
        "--enable_dependency_cache",
        _bool_str(dependency_caching),
        "--manifest_cache",
        manifest_cache,
        "--replace_scm_with_registry",
        _bool_str(replace_scm_with_registry),
        "--use_registry_identity_for_scm",
        _bool_str(use_registry_identity_for_scm),
    ]

    data = []

    if netrc:
        extra_args.extend(["--netrc_file", "$(rootpath %s)" % netrc])
        data.append(netrc)

    if registries:
        extra_args.extend(["--registries_json", "$(rootpath %s)" % registries])
        data.append(registries)

    if env:
        for k, v in env.items():
            extra_args.extend(["--env", "%s=%s" % (k, v)])

    manifest_flags = _manifest_swiftc_flags()
    if manifest_flags:
        extra_args.extend(["--manifest_swiftc_flags", manifest_flags])

    swift_worker_binary(
        name = name,
        tool = "@rules_swift_package_manager//tools/swift_package_cmd",
        extra_args = extra_args,
        data = data,
        **kwargs
    )

swift_package_tool_testing = struct(
    manifest_swiftc_flags = _manifest_swiftc_flags,
)
