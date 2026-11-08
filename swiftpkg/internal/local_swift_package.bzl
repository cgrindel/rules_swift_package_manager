"""Implementation of `local_swift_package`."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load(
    "@bazel_tools//tools/build_defs/repo:utils.bzl",
    "update_attrs",
)
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
load(":manifest_swiftc_args.bzl", "manifest_swiftc_args")
load(":pkg_ctxs.bzl", "pkg_ctxs")
load(":repo_rules.bzl", "repo_rules")
load(":repository_utils.bzl", "repository_utils")

# Ignore the .build directory because we will need to create our own
_CODE_IGNORE_LIST = [".", "..", ".build"]

# Files at the top of a package that make it a Bazel package or repository too.
_BAZEL_FILES = ["BUILD", "BUILD.bazel", "MODULE.bazel", "REPO.bazel", "WORKSPACE", "WORKSPACE.bazel"]

# Where SwiftPM finds a target that names no path.
_DEFAULT_TARGET_DIRS = ["Sources", "Source", "src", "srcs", "Tests", "Plugins"]

def _watch_tree(repository_ctx, path):
    # Watch directory to ensure the repo is refetched if new files are added to the local package.
    # watch_tree was added in Bazel 7.1.0 so we need to check that it exists before calling it.
    if hasattr(repository_ctx, "watch_tree"):
        repository_ctx.watch_tree(path)

def _list_contents(repository_ctx, repo_dir, path):
    exec_result = repository_ctx.execute(
        ["ls", "-a", "-1", path],
        working_directory = repo_dir,
    )
    if exec_result.return_code != 0:
        fail("Failed to list the contents of", path, ".\n", exec_result.stderr)

    results = []
    for entry in exec_result.stdout.splitlines():
        if lists.contains(_CODE_IGNORE_LIST, entry):
            continue
        results.append(paths.join(path, entry))
    return results

def _copy_package(repository_ctx, repo_dir, orig_code_path, orig_files, env):
    """Copies a package's top-level files and its targets' directories, without Bazel files."""
    orig_dirs = {}
    for orig_file in orig_files:
        base = paths.basename(orig_file)
        if repository_ctx.path(orig_file).is_dir:
            orig_dirs[base] = orig_file
        elif base not in _BAZEL_FILES and not base.startswith("."):
            repository_ctx.watch(orig_file)
            _copy(repository_ctx, orig_file, repo_dir)

    # The manifest names the targets' directories.
    dump = repository_utils.parsed_json_from_spm_command(
        repository_ctx,
        ["swift", "package"] + manifest_swiftc_args.BAZEL_DEFINE + ["dump-package"],
        env = env,
        working_directory = repo_dir,
    )
    target_paths = [paths.normalize(t["path"]) for t in dump["targets"] if t.get("path")]
    if len(target_paths) < len(dump["targets"]):
        target_paths.extend(_DEFAULT_TARGET_DIRS)
    if "." in target_paths:
        # A target at the package root can use any of its directories.
        target_paths.extend([
            name
            for name in orig_dirs
            if not name.startswith(".") and not name.startswith("bazel-")
        ])
    for target_path in {p: None for p in target_paths}.keys():
        if target_path.startswith("..") or target_path.split("/")[0] not in orig_dirs:
            continue
        orig_path = paths.join(orig_code_path, target_path)
        if not repository_ctx.path(orig_path).exists:
            continue
        _watch_tree(repository_ctx, orig_path)
        dest = paths.dirname(paths.join(repo_dir, target_path))
        repository_ctx.execute(["mkdir", "-p", dest])
        _copy(repository_ctx, orig_path, dest)

    repo_rules.remove_bazel_files(repository_ctx, repo_dir)

def _copy(repository_ctx, src, dest_dir):
    exec_result = repository_ctx.execute(["cp", "-RL", src, dest_dir])
    if exec_result.return_code != 0:
        fail("Failed to copy {} to {}.\n{}".format(src, dest_dir, exec_result.stderr))

def _local_swift_package_impl(repository_ctx):
    repo_dir = str(repository_ctx.path("."))
    env = repo_rules.get_exec_env(repository_ctx)
    repo_rules.check_spm_version(repository_ctx, env = env)

    orig_code_path = repository_ctx.attr.path
    if not paths.is_absolute(orig_code_path):
        orig_code_path = paths.join(
            str(repository_ctx.workspace_root),
            orig_code_path,
        )

    orig_files = _list_contents(
        repository_ctx,
        str(repository_ctx.workspace_root),
        orig_code_path,
    )

    if [f for f in orig_files if paths.basename(f) in _BAZEL_FILES]:
        # The package is a Bazel package too: its BUILD files would split the
        # generated package, so copy what its targets use and remove them.
        _copy_package(repository_ctx, repo_dir, orig_code_path, orig_files, env)
    else:
        # Create symlinks to top-level files and directories from the original path
        # to the repo rule repo_dir
        _watch_tree(repository_ctx, orig_code_path)
        for orig_file in orig_files:
            base = paths.basename(orig_file)
            link_name = paths.join(repo_dir, base)
            repository_ctx.symlink(orig_file, link_name)

    # Remove the `.swift-version` symlink (the original file in the user's
    # source tree is preserved) so that Swift toolchain proxies do not require
    # a specific Swift version when running SPM commands.
    repo_rules.remove_swift_version_file(repository_ctx, repo_dir)

    # Create the WORKSPACE
    repo_rules.write_workspace_file(repository_ctx, repo_dir)

    # Generate the build file
    cached_json_directory = None
    if repository_ctx.attr.cached_json_directory:
        cached_json_directory = paths.join(
            str(repository_ctx.workspace_root),
            repository_ctx.attr.cached_json_directory,
        )

    pkg_ctx = pkg_ctxs.read(
        repository_ctx,
        repo_dir,
        env,
        cached_json_directory,
        target_deps = repository_ctx.attr.target_deps,
        system_sdk_deps = repository_ctx.attr.system_sdk_deps,
        binary_target_deps = repository_ctx.attr.binary_target_deps,
        module_aliases = repository_ctx.attr.module_aliases,
        dep_module_aliases = repository_ctx.attr.dep_module_aliases,
        bazel_target_mods = repository_ctx.attr.bazel_target_mods,
    )

    repo_rules.download_artifacts(repository_ctx, pkg_ctx)

    repo_rules.gen_build_files(repository_ctx, pkg_ctx)

    return update_attrs(repository_ctx.attr, _ALL_ATTRS.keys(), {})

_PATH_ATTRS = {
    "path": attr.string(
        doc = """\
The path to the local Swift package directory. This can be an absolute path or \
a path relative to the workspace root. The `swift_deps` module extension stores \
a workspace-relative path here whenever the package is inside the workspace \
root so that the lock file remains portable across machines.\
""",
        mandatory = True,
    ),
}

_ALL_ATTRS = dicts.add(
    repo_rules.env_attrs,
    repo_rules.swift_attrs,
    _PATH_ATTRS,
    {
        "build_file": attr.label(
            doc = "When used, the provided BUILD file will be used instead of generating one.",
        ),
        "cached_json_directory": attr.string(),
    },
)

local_swift_package = repository_rule(
    implementation = _local_swift_package_impl,
    attrs = _ALL_ATTRS,
    doc = "Used to build a local Swift package.",
)
