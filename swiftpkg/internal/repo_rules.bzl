"""Module containing shared definitions and functions for repository rules."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:versions.bzl", "versions")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "read_netrc", "read_user_netrc", "use_netrc")
load(":artifact_infos.bzl", "artifact_infos")
load(":build_files.bzl", "build_files")
load(":pkginfos.bzl", "target_types")
load(":repository_files.bzl", "repository_files")
load(":spm_versions.bzl", "spm_versions")
load(":swiftpkg_build_files.bzl", "swiftpkg_build_files")

_swift_attrs = {
    "bazel_package_name": attr.string(
        doc = "The short name for the Swift package's Bazel repository.",
    ),
    "dependencies_index": attr.label(
        doc = """\
A JSON file that contains a mapping of Swift products and Swift modules.\
""",
    ),
}

_env_attrs = {
    "env": attr.string_dict(
        doc = """\
Environment variables that will be passed to the execution environments for \
this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM \
package description generation)\
""",
    ),
}

_DEVELOPER_DIR_ENV = "DEVELOPER_DIR"

def _get_exec_env(repository_ctx):
    """Creates a `dict` of environment variables which will be past to all execution environments for this rule.

    Args:
        repository_ctx: A `repository_ctx` instance.

    Returns:
        A `dict` of environment variables which will be used for execution environments for this rule.
    """

    # If the DEVELOPER_DIR is specified in the environment, it will override
    # the value which may be specified in the env attribute.
    env = dicts.add(repository_ctx.attr.env)
    dev_dir = repository_ctx.os.environ.get(_DEVELOPER_DIR_ENV)
    if dev_dir:
        env[_DEVELOPER_DIR_ENV] = dev_dir
    return env

def _check_spm_version(repository_ctx, env = {}):
    min_spm_ver = "5.4.0"
    spm_ver = spm_versions.get(repository_ctx, env = env)
    if not versions.is_at_least(threshold = min_spm_ver, version = spm_ver):
        fail("""\
`rules_swift_package_manager` requires that Swift Package Manager be version %s or \
higher. Found version %s installed.\
""" % (min_spm_ver, spm_ver))

def _gen_build_files(repository_ctx, pkg_ctx):
    pkg_info = pkg_ctx.pkg_info

    # Create Bazel declarations for the Swift package targets
    bld_files = []
    for target in pkg_info.targets:
        # Unfortunately, Package.resolved does not contain test-only external
        # dependencies. So, we need to skip generating test targets. If a target
        # does not have any product memberships, it is a testonly
        # if target.type == "test" or len(target.product_memberships) == 0:
        if target.type == "test":
            continue

        artifact_infos = []
        if target.type == target_types.binary:
            if target.artifact_download_info != None:
                artifact_infos = _download_artifact(
                    repository_ctx,
                    target.artifact_download_info,
                    target.path,
                )
            else:
                artifact_infos = _artifact_infos_from_path(
                    repository_ctx,
                    target.path,
                )

        bld_file = swiftpkg_build_files.new_for_target(
            repository_ctx,
            pkg_ctx,
            target,
            artifact_infos,
        )

        if bld_file == None:
            continue
        bld_files.append(bld_file)

    # Create Bazel declarations for the targets
    bld_files.append(swiftpkg_build_files.new_for_products(pkg_ctx))

    # Write the build file
    root_bld_file = build_files.merge(*bld_files)
    build_files.write(repository_ctx, root_bld_file, pkg_info.path)

def _write_workspace_file(repository_ctx, repoDir):
    path = paths.join(repoDir, "WORKSPACE")
    repo_name = repository_ctx.name
    content = """\
workspace(name = "{}")
""".format(repo_name)
    repository_ctx.file(path, content = content, executable = False)

def _artifact_infos_from_path(repository_ctx, path):
    if path.endswith(".xcframework"):
        xcframework_dirs = [path]
    else:
        # Collect artifact info about contents of the downloaded artifact
        xcframework_dirs = repository_files.list_directories_under(
            repository_ctx,
            path,
            max_depth = 1,
            by_name = "*.xcframework",
        )
    return [
        artifact_infos.new_xcframework_info_from_files(repository_ctx, xf)
        for xf in xcframework_dirs
    ]

def _download_artifact(repository_ctx, artifact_download_info, path):
    url = artifact_download_info.url
    auth = _get_auth(repository_ctx, [url])

    result = repository_ctx.download_and_extract(
        url = url,
        output = path,
        sha256 = artifact_download_info.checksum,
        auth = auth,
    )
    if not result.success:
        fail("Failed to download artifact. url: {url}, sha256: {sha256}".format(
            url = artifact_download_info.url,
            sha256 = artifact_download_info.checksum,
        ))
    return _artifact_infos_from_path(repository_ctx, path)

# Copied from "@bazel_tools//tools/build_defs/repo:utils.bzl". Availaible starting with 7.1.0
def _get_auth(ctx, urls):
    """Utility function to obtain the correct auth dict for a list of urls from .netrc file.

    Support optional netrc and auth_patterns attributes if available.

    Args:
      ctx: The repository context of the repository rule calling this utility
        function.
      urls: the list of urls to read

    Returns:
      the auth dict which can be passed to repository_ctx.download
    """
    if hasattr(ctx.attr, "netrc") and ctx.attr.netrc:
        netrc = read_netrc(ctx, ctx.attr.netrc)
    elif "NETRC" in ctx.os.environ:
        netrc = read_netrc(ctx, ctx.os.environ["NETRC"])
    else:
        netrc = read_user_netrc(ctx)
    auth_patterns = {}
    if hasattr(ctx.attr, "auth_patterns") and ctx.attr.auth_patterns:
        auth_patterns = ctx.attr.auth_patterns
    return use_netrc(netrc, urls, auth_patterns)

repo_rules = struct(
    check_spm_version = _check_spm_version,
    env_attrs = _env_attrs,
    gen_build_files = _gen_build_files,
    get_exec_env = _get_exec_env,
    swift_attrs = _swift_attrs,
    write_workspace_file = _write_workspace_file,
)
