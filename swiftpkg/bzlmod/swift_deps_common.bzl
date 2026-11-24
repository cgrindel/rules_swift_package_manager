"""Helpers shared by the v1 and v2 declarations of the `swift_deps` extension.

`swift_deps.bzl` loads `slice_declarations.bzl`, so the helpers that both need
live here to avoid a load cycle.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//swiftpkg/internal:bazel_repo_names.bzl", "bazel_repo_names")
load("//swiftpkg/internal:slices.bzl", "slices")

# MARK: - Package repos

_PACKAGE_REPOS_REPO_NAME = "swift_deps_package_repos"

_PACKAGE_REPOS_FILE = "package_repos.json"

def _swift_deps_package_repos_impl(repository_ctx):
    repository_ctx.file(
        _PACKAGE_REPOS_FILE,
        content = json.encode_indent(
            {"repo_names": repository_ctx.attr.repo_names},
            indent = "  ",
        ),
        executable = False,
    )
    repository_ctx.file(
        "BUILD.bazel",
        content = 'exports_files(["{}"])\n'.format(_PACKAGE_REPOS_FILE),
        executable = False,
    )

swift_deps_package_repos = repository_rule(
    implementation = _swift_deps_package_repos_impl,
    attrs = {
        "repo_names": attr.string_list(
            doc = "The names of every Swift package repository declared by the extension.",
        ),
    },
    doc = "Lists the Swift package repositories declared by the `swift_deps` extension.",
)

def _declare_package_repos(repo_names, package_repos_rule = swift_deps_package_repos):
    """Declares the repository that lists every package repository.

    Each package repository reads it to find the effective minimum OS
    versions of the dependencies that exist without failing on ones that do
    not.

    Args:
        repo_names: The package repository names as a `list` of `string`.
        package_repos_rule: The repository rule. Tests pass a fake.

    Returns:
        The label `string` of the JSON file to pass as `package_repos`.
    """
    package_repos_rule(
        name = _PACKAGE_REPOS_REPO_NAME,
        repo_names = sorted(repo_names),
    )
    return "@{}//:{}".format(_PACKAGE_REPOS_REPO_NAME, _PACKAGE_REPOS_FILE)

# MARK: - Inference

# Keep inference ownership separate from legacy configure_package settings:
# dependency modules must not change the root's inference policy.
INFERENCE_KEYS = ["system_sdk_deps", "binary_target_deps"]

def _record_inference_packages(config, dependencies):
    # Include unresolved dependencies so overrides do not block package resolve.
    # Record both accepted names even if the package-name override takes priority.
    for dep in dependencies:
        for name in [dep.name, bazel_repo_names.from_identity(dep.identity)]:
            config.available_names[name] = True
            if name in config.packages:
                config.matched_names[name] = True

def _inference_settings(config, package_name, repo_name):
    # Match configure_package's existing package-name-before-repository lookup.
    overrides = config.packages.get(
        package_name,
        config.packages.get(repo_name, {}),
    )
    settings = dict(config.defaults)
    for key in INFERENCE_KEYS:
        value = overrides.get(key, "inherit")
        if value != "inherit":
            settings[key] = value == "on"
    return settings

# MARK: - Package repository kwargs

def _build_file_conflict_error(package_name, build_file, target_mods):
    """Check that target modifications are not combined with a `build_file`.

    Args:
        package_name: The name of the Swift package as a `string`.
        build_file: The `build_file` override from the `configure_package` tag,
            or `None`.
        target_mods: The encoded target modifications as a `string`.

    Returns:
        A `string` describing the problem, or `None` if there is none.
    """
    if not build_file or not target_mods:
        return None
    return """\
Target modifications cannot be applied to package '{package}' because its \
`configure_package` tag supplies a complete `build_file` override. Remove the \
override or apply the modifications in that BUILD file.\
""".format(package = package_name)

def _config_pkg_for(config_pkgs, dep):
    """The `configure_package` tag for a dependency, by name then repo name."""
    config_pkg = config_pkgs.get(dep.name)
    if config_pkg == None:
        config_pkg = config_pkgs.get(bazel_repo_names.from_identity(dep.identity))
    return config_pkg

def _pkg_repo_kwargs(
        name,
        dep,
        config_pkg,
        make_files_read_only,
        local_path,
        target_deps,
        module_aliases,
        dep_module_aliases,
        target_mods,
        package_repos,
        inference_settings):
    """Builds the package repository kwargs that v1 and v2 share.

    The caller adds the rest. v1 adds `env`, `env_inherit`,
    `cached_json_directory`, `registries`, `replace_scm_with_registry`,
    `resolved`, and `netrc`. v2 adds the cached-manifest attributes and
    `netrc`.

    Args:
        name: The repository name.
        dep: A `pkginfos.new_dependency` struct.
        config_pkg: The `configure_package` tag or `None`.
        make_files_read_only: The `from_package` setting. Only `git` and
            `registry` repositories take it.
        local_path: For a local dep, the path to store in the repository
            (workspace-relative when possible). Ignored otherwise.
        target_deps: The `target_deps` of the `configure_package` tag.
        module_aliases: A `dict` of the SE-0339 aliases of this package.
        dep_module_aliases: The JSON of all aliases by identity, or `""`.
        target_mods: The encoded target modifications as a `string`.
        package_repos: The label `string` from `declare_package_repos`.
        inference_settings: A `dict` from `inference_settings`.

    Returns:
        A `struct(kind, kwargs)`. `kind` is `git`, `local`, or `registry`,
        naming the `package_rules` member to call.
    """
    build_file = config_pkg.build_file if config_pkg else None
    build_file_conflict = _build_file_conflict_error(
        dep.name,
        build_file,
        target_mods,
    )
    if build_file_conflict != None:
        fail(build_file_conflict)
    kwargs = dict(
        name = name,
        bazel_package_name = name,
        build_file = build_file,
        target_deps = target_deps,
        module_aliases = module_aliases,
        dep_module_aliases = dep_module_aliases,
        bazel_target_mods = target_mods,
        package_repos = package_repos,
        **inference_settings
    )
    if dep.source_control:
        pin = dep.source_control.pin
        kwargs.update(
            commit = pin.state.revision,
            remote = pin.location,
            version = pin.state.version,
            dependencies_index = None,
            make_files_read_only = make_files_read_only,
            init_submodules = config_pkg.init_submodules if config_pkg else None,
            recursive_init_submodules = (
                config_pkg.recursive_init_submodules if config_pkg else None
            ),
            patch_args = config_pkg.patch_args if config_pkg else None,
            patch_cmds = config_pkg.patch_cmds if config_pkg else None,
            patch_cmds_win = config_pkg.patch_cmds_win if config_pkg else None,
            patch_tool = config_pkg.patch_tool if config_pkg else None,
            patches = config_pkg.patches if config_pkg else None,
            publicly_expose_all_targets = (
                config_pkg.publicly_expose_all_targets if config_pkg else None
            ),
        )
        return struct(kind = "git", kwargs = kwargs)
    if dep.file_system:
        if paths.is_absolute(local_path):
            # buildifier: disable=print
            print("""
WARNING: local Swift package '{identity}' resolves to '{path}', which is \
outside the Bazel workspace root. Its path will be stored as an absolute path \
in the lock file and will not be portable across machines.\
""".format(identity = dep.identity, path = local_path))
        kwargs.update(
            path = local_path,
            dependencies_index = None,
        )
        return struct(kind = "local", kwargs = kwargs)
    if dep.registry:
        kwargs.update(
            id = dep.registry.pin.identity,
            make_files_read_only = make_files_read_only,
            version = dep.registry.pin.state.version,
        )
        return struct(kind = "registry", kwargs = kwargs)
    fail("Swift package `{}` has no source.".format(dep.identity))

# MARK: - Mode

def _mixed_modes_error(modules):
    """Checks that the `from_package` tags do not mix v1 and v2.

    Args:
        modules: The value of `module_ctx.modules`.

    Returns:
        `None` when every tag is v1 or every tag is v2; otherwise, an error
        `string`.
    """
    has_v1 = False
    has_v2 = False
    for mod in modules:
        for tag in mod.tags.from_package:
            if slices.is_v2_tag(tag):
                has_v2 = True
            else:
                has_v1 = True
    if has_v1 and has_v2:
        return (
            "mixing v1 and v2 `from_package` tags is not supported; " +
            "migrate every tag to slices"
        )
    return None

swift_deps_common = struct(
    build_file_conflict_error = _build_file_conflict_error,
    config_pkg_for = _config_pkg_for,
    declare_package_repos = _declare_package_repos,
    inference_settings = _inference_settings,
    mixed_modes_error = _mixed_modes_error,
    pkg_repo_kwargs = _pkg_repo_kwargs,
    record_inference_packages = _record_inference_packages,
)
