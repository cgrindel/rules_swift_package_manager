"""Implementation for `swift_package`."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:versions.bzl", "versions")
load("@bazel_tools//tools/build_defs/repo:git_worker.bzl", "git_repo")
load(
    "@bazel_tools//tools/build_defs/repo:utils.bzl",
    "patch",
    "update_attrs",
    "workspace_and_buildfile",
)
load(":package_infos.bzl", "package_infos")
load(":spm_versions.bzl", "spm_versions")

# The implementation of this repository rule is heavily influenced by the
# implementation for git_repository.

# MARK: - Environment Variables

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

def _clone_or_update_repo(repository_ctx, directory):
    if ((not repository_ctx.attr.tag and not repository_ctx.attr.commit and not repository_ctx.attr.branch) or
        (repository_ctx.attr.tag and repository_ctx.attr.commit) or
        (repository_ctx.attr.tag and repository_ctx.attr.branch) or
        (repository_ctx.attr.commit and repository_ctx.attr.branch)):
        fail("Exactly one of commit, tag, or branch must be provided")

    git_ = git_repo(repository_ctx, directory)

    # Do not include shallow_since as required for the canonical form. I am not
    # sure how to determine that when generating the swift_package declarations
    return {"commit": git_.commit}

def _update_git_attrs(orig, keys, override):
    result = update_attrs(orig, keys, override)

    # if we found the actual commit, remove all other means of specifying it,
    # like tag or branch.
    if "commit" in result:
        result.pop("tag", None)
        result.pop("branch", None)
    return result

def _gen_build_files(repository_ctx, pkg_info):
    targets_pkg = repository_ctx.attr.targets_pkg
    targets_bld_file = swiftpkg_bld_decls.build_file_from_pkg_info(pkg_info)
    targets_bld_path = paths.join(pkg_info.path, targets_pkg, "BUILD.bazel")
    repository_ctx.file(
        targets_bld_path,
        content = starlark_codegen.to_starlark(targets_bld_file),
        executable = False,
    )

    # TODO(chuck): Add products package

def _swift_package_impl(repository_ctx):
    directory = str(repository_ctx.path("."))
    env = _get_exec_env(repository_ctx)
    _check_spm_version(repository_ctx, env = env)

    # Download the repo
    update = _clone_or_update_repo(repository_ctx, directory)

    # Get the package info
    pkg_info = package_infos.get(repository_ctx, directory, env = env)

    # Generate the WORKSPACE file
    workspace_and_buildfile(repository_ctx)

    # Generate the build file
    _gen_build_files(repository_ctx, pkg_info)

    # Apply any patches
    patch(repository_ctx)

    # Remove the git stuff
    repository_ctx.delete(repository_ctx.path(".git"))

    # Return attributes that make this reproducible
    return _update_git_attrs(repository_ctx.attr, _COMMON_ATTRS.keys(), update)

_GIT_ATTRS = {
    "branch": attr.string(
        default = "",
        doc =
            "branch in the remote repository to checked out." +
            " Precisely one of branch, tag, or commit must be specified.",
    ),
    "commit": attr.string(
        mandatory = True,
        doc = """\
The commit or revision to download from version control.\
""",
    ),
    "init_submodules": attr.bool(
        default = False,
        doc = "Whether to clone submodules in the repository.",
    ),
    "recursive_init_submodules": attr.bool(
        default = False,
        doc = "Whether to clone submodules recursively in the repository.",
    ),
    "remote": attr.string(
        mandatory = True,
        doc = """\
The version control location from where the repository should be downloaded.\
""",
    ),
    "shallow_since": attr.string(
        default = "",
        doc =
            "an optional date, not after the specified commit; the " +
            "argument is not allowed if a tag is specified (which allows " +
            "cloning with depth 1). Setting such a date close to the " +
            "specified commit allows for a more shallow clone of the " +
            "repository, saving bandwidth " +
            "and wall-clock time.",
    ),
    "tag": attr.string(
        default = "",
        doc =
            "tag in the remote repository to checked out." +
            " Precisely one of branch, tag, or commit must be specified.",
    ),
    "verbose": attr.bool(default = False),
}

_WORKSPACE_AND_BUILD_FILE_ATTRS = {
    "build_file": attr.label(
        allow_single_file = True,
        doc =
            "The file to use as the BUILD file for this repository." +
            "This attribute is an absolute label (use '@//' for the main " +
            "repo). The file does not need to be named BUILD, but can " +
            "be (something like BUILD.new-repo-name may work well for " +
            "distinguishing it from the repository's actual BUILD files. " +
            "Either build_file or build_file_content must be specified.",
    ),
    "build_file_content": attr.string(
        doc =
            "The content for the BUILD file for this repository. " +
            "Either build_file or build_file_content must be specified.",
    ),
    "workspace_file": attr.label(
        doc =
            "The file to use as the `WORKSPACE` file for this repository. " +
            "Either `workspace_file` or `workspace_file_content` can be " +
            "specified, or neither, but not both.",
    ),
    "workspace_file_content": attr.string(
        doc =
            "The content for the WORKSPACE file for this repository. " +
            "Either `workspace_file` or `workspace_file_content` can be " +
            "specified, or neither, but not both.",
    ),
}

_PATCH_ATTRS = {
    "patch_args": attr.string_list(
        default = ["-p0"],
        doc =
            "The arguments given to the patch tool. Defaults to -p0, " +
            "however -p1 will usually be needed for patches generated by " +
            "git. If multiple -p arguments are specified, the last one will take effect." +
            "If arguments other than -p are specified, Bazel will fall back to use patch " +
            "command line tool instead of the Bazel-native patch implementation. When falling " +
            "back to patch command line tool and patch_tool attribute is not specified, " +
            "`patch` will be used.",
    ),
    "patch_cmds": attr.string_list(
        default = [],
        doc = "Sequence of Bash commands to be applied on Linux/Macos after patches are applied.",
    ),
    "patch_cmds_win": attr.string_list(
        default = [],
        doc = "Sequence of Powershell commands to be applied on Windows after patches are " +
              "applied. If this attribute is not set, patch_cmds will be executed on Windows, " +
              "which requires Bash binary to exist.",
    ),
    "patch_tool": attr.string(
        default = "",
        doc = "The patch(1) utility to use. If this is specified, Bazel will use the specified " +
              "patch tool instead of the Bazel-native patch implementation.",
    ),
    "patches": attr.label_list(
        default = [],
        doc =
            "A list of files that are to be applied as patches after " +
            "extracting the archive. By default, it uses the Bazel-native patch implementation " +
            "which doesn't support fuzz match and binary patch, but Bazel will fall back to use " +
            "patch command line tool if `patch_tool` attribute is specified or there are " +
            "arguments other than `-p` in `patch_args` attribute.",
    ),
}

_ENV_ATTRS = {
    "env": attr.string_dict(
        doc = """\
Environment variables that will be passed to the execution environments for \
this repository rule. (e.g. SPM version check, SPM dependency resolution, SPM \
package description generation)\
""",
    ),
}

_CODEGEN_ATTRS = {
    "products_pkg": attr.string(
        default = "",
        doc = """\
The name of the Bazel package under which the Bazel declarations for the Swift \
products will be created.  Bazel declarations for the Swift package products are \
placed in their own Bazel package to avoid name conflicts with target \
declarations.\
""",
    ),
    "targets_pkg": attr.string(
        default = "swiftpkg_targets",
        doc = """\
The name of the Bazel package under which the Bazel declarations for the Swift \
targets will be created.  Bazel declarations for the Swift package targets are \
placed in their own Bazel package to avoid name conflicts with product \
declarations.\
""",
    ),
}

_COMMON_ATTRS = dicts.add(
    _PATCH_ATTRS,
    _WORKSPACE_AND_BUILD_FILE_ATTRS,
    _GIT_ATTRS,
    _ENV_ATTRS,
    _CODEGEN_ATTRS,
)

swift_package = repository_rule(
    implementation = _swift_package_impl,
    attrs = _COMMON_ATTRS,
    doc = "",
)
