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
load(":starlark_codegen.bzl", scg = "starlark_codegen")
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

_env_attr = {
    "env": attr.string_dict(
        doc = """\
Environment variables that will be passed to the execution environments for \
this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM \
package description generation)\
""",
    ),
}

_env_attrs = dicts.add(
    _env_attr,
    {
        "env_inherit": attr.string_list(
            doc = """\
Environment variables to inherit from the external environment that will be \
passed to the execution environments for this repository rule. (e.g. SPM version check, \
SPM dependency resolution, SPM package description generation)\
""",
        ),
    },
)

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
    env_inherit = repository_ctx.attr.env_inherit
    for key in env_inherit:
        env[key] = repository_ctx.getenv(key)
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

    bld_files = []

    licenses = repository_files.find_license_files(repository_ctx)
    bld_files.append(
        # Pick the shortest name, in order to prefer `LICENSE` over
        # `LICENSE.md`
        swiftpkg_build_files.new_for_license(
            pkg_info,
            sorted(licenses, key = len)[0] if licenses else None,
        ),
    )

    # Create Bazel declarations for the Swift package targets
    for target in pkg_info.targets:
        # Unfortunately, Package.resolved does not contain test-only external
        # dependencies. So, we need to skip generating test targets.
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

    # Export the pkg_info.json
    exports_files = scg.new_fn_call("exports_files", ["pkg_info.json"])
    bld_files.append(build_files.new(decls = [exports_files]))

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
            by_name = "*.xcframework",
        )

    # NOTE: SPM validates the `.xcframework` paths by decoding the `Info.plist` file.
    # This would be more involved to do in Starlark, so instead we'll assume
    # that a `.xcframework` dir is a potential candidate if it contains a
    # `Info.plist` file without checking the file contents.
    # See: https://github.com/swiftlang/swift-package-manager/blob/c26c12f54357fb7246c0bdbe3483105389f056b8/Sources/Workspace/Workspace%2BBinaryArtifacts.swift#L771-L780
    xcframework_dirs = [
        xf
        for xf in xcframework_dirs
        if repository_files.path_exists(repository_ctx, paths.join(xf, "Info.plist"))
    ]

    # If multiple found, use the last one which is what SPM currently does:
    # https://github.com/swiftlang/swift-package-manager/blob/c26c12f54357fb7246c0bdbe3483105389f056b8/Sources/Workspace/Workspace%2BBinaryArtifacts.swift#L699-L723
    if len(xcframework_dirs) > 1:
        # buildifier: disable=print
        print("""\
WARNING: Found multiple XCFramework binary artifacts in the downloaded artifact: \
{xcframework_dirs}, using the last one.
""".format(
            xcframework_dirs = xcframework_dirs,
        ))
        xcframework_dirs = xcframework_dirs[-1:]

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

def _remove_bazel_files(repository_ctx, directory):
    files = ["BUILD.bazel", "BUILD", "WORKSPACE", "WORKSPACE.bazel"]
    for file in files:
        repository_files.find_and_delete_files(repository_ctx, directory, file)

def _remove_modulemaps(repository_ctx, directory, targets):
    repository_files.find_and_delete_files(
        repository_ctx,
        directory,
        "module.modulemap",
        exclude_paths = [
            # Framework modulemaps don't cause issues, and are needed
            "**/*.framework/*",
        ] + [
            # We need to leave any modulemaps that we are passing into
            # `objc_library`
            target.clang_src_info.modulemap_path
            for target in targets
            if target.clang_src_info and target.clang_src_info.modulemap_path
        ],
    )

repo_rules = struct(
    check_spm_version = _check_spm_version,
    env_attr = _env_attr,
    env_attrs = _env_attrs,
    gen_build_files = _gen_build_files,
    get_exec_env = _get_exec_env,
    remove_bazel_files = _remove_bazel_files,
    remove_modulemaps = _remove_modulemaps,
    swift_attrs = _swift_attrs,
    write_workspace_file = _write_workspace_file,
)
