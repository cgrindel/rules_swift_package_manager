"""Implementation of `local_swift_package`."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load(
    "@bazel_tools//tools/build_defs/repo:utils.bzl",
    "update_attrs",
)
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
load(":pkg_ctxs.bzl", "pkg_ctxs")
load(":repo_rules.bzl", "repo_rules")

# Ignore the .build directory because we will need to create our own
_CODE_IGNORE_LIST = [".", "..", ".build"]

def _list_contents(repository_ctx, repo_dir, path):
    # Watch directory to ensure the repo is refetched if new files are added to the local package.
    # watch_tree was added in Bazel 7.1.0 so we need to check that it exists before calling it.
    if hasattr(repository_ctx, "watch_tree"):
        repository_ctx.watch_tree(path)

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

    # Create symlinks to top-level files and directories from the original path
    # to the repo rule repo_dir
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

    dump_manifest, desc_manifest = pkg_ctxs.read_cached_manifests(repository_ctx)
    pkg_ctx = pkg_ctxs.read(
        repository_ctx,
        repo_dir,
        env,
        cached_json_directory,
        target_deps = repository_ctx.attr.target_deps,
        dump_manifest = dump_manifest,
        desc_manifest = desc_manifest,
    )
    repo_rules.gen_build_files(repository_ctx, pkg_ctx)

    return update_attrs(repository_ctx.attr, _ALL_ATTRS.keys(), {})

_PATH_ATTRS = {
    "path": attr.string(
        doc = "The path to the local Swift package directory. This can be an absolute path or a relative path to the workspace root.",
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
        "cached_desc_manifest": attr.label(
            allow_single_file = [".json"],
            doc = """\
Pre-generated `desc.json` for this package, produced by \
`bazel run @swift_package//:cache`. When provided alongside \
`cached_dump_manifest`, the repository rule reads these files instead \
of invoking `swift package describe`. See GH-2140.\
""",
        ),
        "cached_dump_manifest": attr.label(
            allow_single_file = [".json"],
            doc = """\
Pre-generated `dump.json` for this package. Always travels with \
`cached_desc_manifest`.\
""",
        ),
        "cached_json_directory": attr.string(
            doc = """\
**Deprecated.** Prefer `cached_dump_manifest` / \
`cached_desc_manifest`, which let the cache live in the consuming \
workspace and be regenerated through the active Bazel Swift worker \
(see GH-2140). Setting both this attribute and the new pair is a hard \
error.\
""",
        ),
    },
)

local_swift_package = repository_rule(
    implementation = _local_swift_package_impl,
    attrs = _ALL_ATTRS,
    doc = "Used to build a local Swift package.",
)
