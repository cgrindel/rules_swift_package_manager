load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(
    "@bazel_tools//tools/build_defs/repo:utils.bzl",
    "update_attrs",
)
load(":pkginfos.bzl", "pkginfos")
load(":repo_rules.bzl", "repo_rules")

def _local_swift_package_impl(repository_ctx):
    directory = str(repository_ctx.path("."))
    env = repo_rules.get_exec_env(repository_ctx)
    repo_rules.check_spm_version(repository_ctx, env = env)

    # Create symlinks to top-level files and directories from the original path
    # to the repo rule directory

    # Create the WORKSPACE
    repo_rules.write_workspace_file(repository_ctx, directory)

    # Get the package info
    pkg_info = pkginfos.get(repository_ctx, directory, env = env)

    # Generate the build file
    repo_rules.gen_build_files(repository_ctx, pkg_info)

    return update_attrs(repository_ctx.attr, _COMMON_ATTRS.keys(), {})

_PATH_ATTRS = {
    "path": attr.string(
        doc = "The path to the local Swift package directory.",
        mandatory = True,
    ),
}

_COMMON_ATTRS = dicts.add(
    repo_rules.env_attrs,
    repo_rules.swift_attrs,
    _PATH_ATTRS,
)

local_swift_package = repository_rule(
    implementation = _local_swift_package_impl,
    attrs = _COMMON_ATTRS,
    doc = "",
)
