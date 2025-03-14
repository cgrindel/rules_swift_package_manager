"""Implementation for `swift_package`."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_tools//tools/build_defs/repo:git_worker.bzl", "git_repo")
load(
    "@bazel_tools//tools/build_defs/repo:utils.bzl",
    "patch",
    "update_attrs",
)
load(":pkg_ctxs.bzl", "pkg_ctxs")
load(":repo_rules.bzl", "repo_rules")

# The implementation of this repository rule is heavily influenced by the
# implementation for git_repository.

# MARK: - Environment Variables

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

def _swift_package_impl(repository_ctx):
    attr = repository_ctx.attr
    directory = str(repository_ctx.path("."))
    env = repo_rules.get_exec_env(repository_ctx)
    repo_rules.check_spm_version(repository_ctx, env = env)
    replace_scm_with_registry = attr.replace_scm_with_registry

    # Download the repo
    update = _clone_or_update_repo(repository_ctx, directory)

    # Apply any patches
    patch(repository_ctx)

    # Remove any Bazel build files.
    repo_rules.remove_bazel_files(repository_ctx, directory)

    # Generate the WORKSPACE file
    repo_rules.write_workspace_file(repository_ctx, directory)

    # If using Swift Package registries we must set any requested
    # flags and the config path for the registries JSON file.
    # NOTE: SPM does not have a flag for setting the exact file path
    # for the registry, instead we must use the parent directory as the
    # config path and SPM finds the registry configuration file there.
    if attr.registries:
        registries_directory = str(repository_ctx.path(attr.registries).dirname)
    else:
        registries_directory = None

    # Generate the build file
    pkg_ctx = pkg_ctxs.read(
        repository_ctx,
        directory,
        env,
        registries_directory = registries_directory,
        replace_scm_with_registry = replace_scm_with_registry,
    )
    repo_rules.gen_build_files(repository_ctx, pkg_ctx)

    # Remove the git stuff
    repository_ctx.delete(repository_ctx.path(".git"))

    # Remove unused modulemaps to prevent module redefinition errors
    repo_rules.remove_modulemaps(repository_ctx, directory, pkg_ctx.pkg_info.targets)

    # Return attributes that make this reproducible
    return _update_git_attrs(repository_ctx.attr, _ALL_ATTRS.keys(), update)

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
        default = True,
        doc = "Whether to clone submodules recursively in the repository.",
    ),
    "registries": attr.label(
        default = None,
        doc = "The registries JSON file for the package if using " +
              "Swift Package Registries.",
    ),
    "remote": attr.string(
        mandatory = True,
        doc = """\
The version control location from where the repository should be downloaded.\
""",
    ),
    "replace_scm_with_registry": attr.bool(
        default = False,
        doc = "Whether to replace SCM references with registry references." +
              " Only used if `registries` is provided.",
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

PATCH_ATTRS = {
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

TOOL_ATTRS = {
    "publicly_expose_all_targets": attr.bool(
        default = False,
        doc = """
Allows to expose internal build targets required for package compilation.
The structure and labels of exposed targets may change in future releases
without requiring a major version bump.
""",
    ),
}

_ALL_ATTRS = dicts.add(
    PATCH_ATTRS,
    TOOL_ATTRS,
    _GIT_ATTRS,
    repo_rules.env_attrs,
    repo_rules.swift_attrs,
    {"version": attr.string(doc = "The resolved version of the package.")},
)

swift_package = repository_rule(
    implementation = _swift_package_impl,
    attrs = _ALL_ATTRS,
    doc = """\
Used to download and build an external Swift package.
""",
)
