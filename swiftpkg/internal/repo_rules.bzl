"""Module containing shared definitions and functions for repository rules."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:versions.bzl", "versions")
load(":build_files.bzl", "build_files")
load(":pkg_ctxs.bzl", "pkg_ctxs")
load(":spm_versions.bzl", "spm_versions")
load(":swiftpkg_build_files.bzl", "swiftpkg_build_files")

_swift_attrs = {
    "module_index": attr.label(
        doc = "The JSON file that contains the module index by name.",
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
`rules_spm` requires that Swift Package Manager be version %s or \
higher. Found version %s installed.\
""" % (min_spm_ver, spm_ver))

def _gen_build_files(repository_ctx, pkg_info):
    repo_name = repository_ctx.name
    pkg_ctx = pkg_ctxs.new(
        pkg_info = pkg_info,
        repo_name = repo_name,
        module_index_json = repository_ctx.read(
            repository_ctx.attr.module_index,
        ),
    )

    # Create Bazel declarations for the Swift package targets
    bld_files = []
    for target in pkg_info.targets:
        bld_file = swiftpkg_build_files.new_for_target(pkg_ctx, target)
        if bld_file == None:
            continue
        bld_files.append(bld_file)

    # Create Bazel declarations for the targets
    bld_files.append(swiftpkg_build_files.new_for_products(pkg_info, repo_name))

    # # DEBUG BEGIN
    # print("*** CHUCK repo_name: ", repo_name)
    # print("*** CHUCK bld_files: ")
    # for idx, item in enumerate(bld_files):
    #     print("*** CHUCK", idx, ":", item)
    # # DEBUG END

    # Write the build file
    root_bld_file = build_files.merge(*bld_files)
    build_files.write(repository_ctx, root_bld_file, pkg_info.path)

def _write_workspace_file(repository_ctx, repoDir):
    path = paths.join(repoDir, "WORKSPACE")
    content = """\
workspace(name = "{}")
""".format(repository_ctx.name)
    repository_ctx.file(path, content = content, executable = False)

repo_rules = struct(
    check_spm_version = _check_spm_version,
    env_attrs = _env_attrs,
    gen_build_files = _gen_build_files,
    get_exec_env = _get_exec_env,
    swift_attrs = _swift_attrs,
    write_workspace_file = _write_workspace_file,
)
