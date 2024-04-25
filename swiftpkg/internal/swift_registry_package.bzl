"""Implementation for `swift_registry_package`."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "update_attrs")
load(":pkg_ctxs.bzl", "pkg_ctxs")
load(":repo_rules.bzl", "repo_rules")
load(":repository_files.bzl", "repository_files")

def _remove_bazel_files(repository_ctx, directory):
    files = ["BUILD.bazel", "BUILD", "WORKSPACE", "WORKSPACE.bazel"]
    for file in files:
        repository_files.find_and_delete_files(repository_ctx, directory, file)

def _swift_registry_package_impl(repository_ctx):
    directory = str(repository_ctx.path("."))
    env = repo_rules.get_exec_env(repository_ctx)
    repo_rules.check_spm_version(repository_ctx, env = env)

    url = repository_ctx.attr.url

    # Works for my case, but the prefix can actually be anything, so this is not sufficient for general use.
    # See `archive-source` command docs:
    # https://github.com/apple/swift-evolution/blob/main/proposals/0292-package-registry-service.md#archive-source-subcommand
    components = url.split("/")
    scope = components[-3]
    name = components[-2]
    prefix = "{}.{}".format(scope, name)

    headers = { 
        "Accept": "application/vnd.swift.registry.v1+zip",
    }

    repository_ctx.download_and_extract(
        url = url,
        # requires bazel 7.1
        headers = headers,
        stripPrefix = prefix,
    )

    # # Remove any Bazel build files.
    _remove_bazel_files(repository_ctx, directory)

    # # Generate the WORKSPACE file
    repo_rules.write_workspace_file(repository_ctx, directory)

    # # Generate the build file
    pkg_ctx = pkg_ctxs.read(repository_ctx, directory, env)
    repo_rules.gen_build_files(repository_ctx, pkg_ctx)

    # # Return attributes that make this reproducible
    return update_attrs(repository_ctx.attr, _ALL_ATTRS.keys(), {})

_URL_ATTRS = {
    "url": attr.string(
        mandatory = True,
        doc = """\
The URL on the registry.\
""",
    ),
}

_ALL_ATTRS = dicts.add(
    _URL_ATTRS,
    repo_rules.env_attrs,
    repo_rules.swift_attrs,
)

swift_registry_package = repository_rule(
    implementation = _swift_registry_package_impl,
    attrs = _ALL_ATTRS,
    doc = """\
Used to download and build an external Swift package from a registry.
""",
)
