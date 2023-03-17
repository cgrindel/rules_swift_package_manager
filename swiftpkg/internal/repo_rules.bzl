"""Module containing shared definitions and functions for repository rules."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:versions.bzl", "versions")
load(":build_files.bzl", "build_files")
load(":repository_utils.bzl", "repository_utils")
load(":spm_versions.bzl", "spm_versions")
load(":swiftpkg_build_files.bzl", "swiftpkg_build_files")

_swift_attrs = {
    "dependencies_index": attr.label(
        doc = """\
A JSON file that contains a mapping of Swift products and Swift modules.\
""",
        mandatory = True,
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
`swift_bazel` requires that Swift Package Manager be version %s or \
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
        if target.type == "test" or len(target.product_memberships) == 0:
            continue
        if target.artifact_download_info != None:
            _download_artifact(repository_ctx, target.artifact_download_info, target.path)
        bld_file = swiftpkg_build_files.new_for_target(repository_ctx, pkg_ctx, target)
        if bld_file == None:
            continue
        bld_files.append(bld_file)

    # Create Bazel declarations for the targets
    bld_files.append(swiftpkg_build_files.new_for_products(pkg_info, pkg_ctx.repo_name))

    # Write the build file
    root_bld_file = build_files.merge(*bld_files)
    build_files.write(repository_ctx, root_bld_file, pkg_info.path)

def _write_workspace_file(repository_ctx, repoDir):
    path = paths.join(repoDir, "WORKSPACE")
    repo_name = repository_utils.repo_name(repository_ctx)
    content = """\
workspace(name = "{}")
""".format(repo_name)
    repository_ctx.file(path, content = content, executable = False)

def _download_artifact(repository_ctx, artifact_download_info, path):
    result = repository_ctx.download_and_extract(
        url = artifact_download_info.url,
        output = path,
        sha256 = artifact_download_info.checksum,
    )
    if not result.success:
        fail("Failed to download artifact. url: {url}, sha256: {sha256}".format(
            url = artifact_download_info.url,
            sha256 = artifact_download_info.checksum,
        ))

repo_rules = struct(
    check_spm_version = _check_spm_version,
    env_attrs = _env_attrs,
    gen_build_files = _gen_build_files,
    get_exec_env = _get_exec_env,
    swift_attrs = _swift_attrs,
    write_workspace_file = _write_workspace_file,
)
