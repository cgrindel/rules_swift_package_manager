"""Implementation for `swift_registry_package`."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "update_attrs")
load(":pkg_ctxs.bzl", "pkg_ctxs")
load(":registry_configs.bzl", "registry_configs")
load(":repo_rules.bzl", "repo_rules")
load(":repository_files.bzl", "repository_files")

def _swift_registry_package_impl(repository_ctx):
    directory = str(repository_ctx.path("."))
    env = repo_rules.get_exec_env(repository_ctx)
    repo_rules.check_spm_version(repository_ctx, env = env)

    id = repository_ctx.attr.id
    version = repository_ctx.attr.version
    components = id.split(".")
    scope = components[0]
    name = components[1]

    registry_config = registry_configs.read(repository_ctx)
    registry_url = registry_configs.get_url_for_scope(registry_config, scope)

    url = "{}/{}/{}/{}.zip".format(registry_url, scope, name, version)

    # TODO:
    # Works for my case, but the prefix can actually be anything, so this is not sufficient for general use.
    # See `archive-source` command docs:
    # https://github.com/apple/swift-evolution/blob/main/proposals/0292-package-registry-service.md#archive-source-subcommand
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

    # Remove any Bazel build files.
    repository_files.remove_bazel_files(repository_ctx, directory)

    # Generate the WORKSPACE file
    repo_rules.write_workspace_file(repository_ctx, directory)

    # Generate the build file
    pkg_ctx = pkg_ctxs.read(repository_ctx, directory, env)
    repo_rules.gen_build_files(repository_ctx, pkg_ctx)

    # Return attributes that make this reproducible
    return update_attrs(repository_ctx.attr, _ALL_ATTRS.keys(), {})

_REGISTRY_ATTRS = {
    "id": attr.string(
        mandatory = True,
        doc = """\
The package identifier.\
""",
    ),
    "version": attr.string(
        mandatory = True,
        doc = """\
The package version.\
""",
    ),
}

_ALL_ATTRS = dicts.add(
    _REGISTRY_ATTRS,
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
