"""Defines the `swift_package_tool_repo` repository rule that creates `swift_worker_binary` targets."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:build_files.bzl", "build_files")
load("//swiftpkg/internal:load_statements.bzl", "load_statements")
load("//swiftpkg/internal:manifest_swiftc_args.bzl", "manifest_swiftc_args")
load("//swiftpkg/internal:repo_rules.bzl", "repo_rules")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:swift_package_tool_attrs.bzl", "swift_package_tool_attrs")

def _bool_str(value):
    return "true" if value else "false"

def _collect_extra_args(repository_ctx, cmd):
    """Builds the extra_args list for the swift_worker_binary target.

    Args:
        repository_ctx: A `repository_ctx` instance.
        cmd: The swift package command ("update" or "resolve").

    Returns:
        A `list` of string arguments.
    """
    attr = repository_ctx.attr
    package_path = attr.package

    # Strip the filename to get the directory.
    parts = package_path.rsplit("/", 1)
    pkg_dir = parts[0] if len(parts) > 1 else ""

    args = [
        "--cmd",
        cmd,
        "--package_path",
        pkg_dir,
        "--build_path",
        attr.build_path,
        "--cache_path",
        attr.cache_path,
        "--config_path",
        attr.config_path,
        "--security_path",
        attr.security_path,
        "--enable_build_manifest_caching",
        _bool_str(attr.manifest_caching),
        "--enable_dependency_cache",
        _bool_str(attr.dependency_caching),
        "--manifest_cache",
        attr.manifest_cache,
        "--replace_scm_with_registry",
        _bool_str(attr.replace_scm_with_registry),
        "--use_registry_identity_for_scm",
        _bool_str(attr.use_registry_identity_for_scm),
    ]

    if attr.netrc:
        args.extend(["--netrc_file", "$(rootpath :.netrc)"])

    if attr.registries:
        args.extend(["--registries_json", "$(rootpath :registries.json)"])

    env_pairs = ["%s=%s" % (k, v) for (k, v) in attr.env.items()] if attr.env else []
    if env_pairs:
        args.extend(["--env", " ".join(env_pairs)])

    manifest_flags = " ".join(manifest_swiftc_args.BAZEL_DEFINE)
    if manifest_flags:
        args.extend(["--manifest_swiftc_flags", manifest_flags])

    return args

def _swift_package_tool_repo_impl(repository_ctx):
    data = []

    if repository_ctx.attr.netrc:
        repository_utils.copy(repository_ctx, repository_ctx.attr.netrc, ".netrc")
        data.append(":.netrc")

    if repository_ctx.attr.registries:
        repository_utils.copy(repository_ctx, repository_ctx.attr.registries, "registries.json")
        data.append(":registries.json")

    update_args = _collect_extra_args(repository_ctx, "update")
    resolve_args = _collect_extra_args(repository_ctx, "resolve")

    common_attrs = {
        "tool": "@rules_swift_package_manager//tools/swift_package_cmd",
    }
    if data:
        common_attrs["data"] = data

    bld_file = build_files.new(
        load_stmts = [
            load_statements.new(
                "@rules_swift_package_manager//swiftpkg:defs.bzl",
                "swift_worker_binary",
            ),
        ],
        decls = [
            build_decls.new(
                "swift_worker_binary",
                name = "update",
                attrs = dicts.add(common_attrs, {"extra_args": update_args}),
            ),
            build_decls.new(
                "swift_worker_binary",
                name = "resolve",
                attrs = dicts.add(common_attrs, {"extra_args": resolve_args}),
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
    doc = "Declares a `@swift_package` repository for using the `swift_worker_binary` targets.",
)
