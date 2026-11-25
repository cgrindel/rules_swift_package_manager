"""Defines the `swift_package_tool_repo` repository rule.

In v1 mode, the rule generates a workspace exposing `swift_worker_binary`
targets named `update` and `resolve` that drive `swift package` commands.

In v2 mode (`slices` is set), it generates `swift_package_tool_rule` targets
named `resolve`, `update` and `cache` that run `swift_deps_tool`.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("//swiftpkg/internal:bools.bzl", "bools")
load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:build_files.bzl", "build_files")
load("//swiftpkg/internal:load_statements.bzl", "load_statements")
load("//swiftpkg/internal:manifest_swiftc_args.bzl", "manifest_swiftc_args")
load("//swiftpkg/internal:repo_rules.bzl", "repo_rules")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:swift_package_tool_args.bzl", "swift_package_tool_args")
load("//swiftpkg/internal:swift_package_tool_attrs.bzl", "swift_package_tool_attrs")

_V2_CMDS = ["resolve", "update", "cache"]

def _collect_extra_args(attr, cmd):
    """Builds the extra_args list for the swift_worker_binary target.

    Args:
        attr: The repository rule attributes (`repository_ctx.attr`).
        cmd: The swift package command ("update" or "resolve").

    Returns:
        A `list` of string arguments.
    """
    pkg_dir = paths.dirname(attr.package)

    args = [
        "--cmd",
        cmd,
        "--package_path",
        pkg_dir,
        "--build_path",
        attr.build_path,
        "--cache_path",
        attr.cache_path,
        "--config_path",
        attr.config_path,
        "--security_path",
        attr.security_path,
        "--enable_build_manifest_caching",
        bools.to_shell_str(attr.manifest_caching),
        "--enable_dependency_cache",
        bools.to_shell_str(attr.dependency_caching),
        "--manifest_cache",
        attr.manifest_cache,
        "--replace_scm_with_registry",
        bools.to_shell_str(attr.replace_scm_with_registry),
        "--use_registry_identity_for_scm",
        bools.to_shell_str(attr.use_registry_identity_for_scm),
    ]

    # The repo rule path copies netrc/registries files into the
    # generated repo (see _swift_package_tool_repo_impl) and references
    # them by local label. The macro path in swift_package_tool.bzl
    # uses $(rootpath <user_label>) directly. Keep both in sync.
    if attr.netrc:
        args.extend(["--netrc_file", "$(rootpath :.netrc)"])

    if attr.registries:
        args.extend(["--registries_json", "$(rootpath :registries.json)"])

    if attr.env:
        for k, v in attr.env.items():
            args.extend(["--env", "%s=%s" % (k, v)])

    manifest_flags = " ".join(manifest_swiftc_args.BAZEL_DEFINE)
    if manifest_flags:
        args.extend(["--manifest_swiftc_flags", manifest_flags])

    return args

def _v1_build_file(attr, data):
    """Returns the v1 BUILD file with `swift_worker_binary` targets.

    Args:
        attr: The repository rule attributes (`repository_ctx.attr`).
        data: A `list` of labels for the files copied into the repository.

    Returns:
        A `struct` as returned by `build_files.new`.
    """
    update_args = _collect_extra_args(attr, "update")
    resolve_args = _collect_extra_args(attr, "resolve")

    common_attrs = {
        "tool": "@rules_swift_package_manager//tools/swift_package_cmd",
    }
    if data:
        common_attrs["data"] = data

    return build_files.new(
        load_stmts = [
            load_statements.new(
                "@rules_swift_package_manager//swiftpkg:defs.bzl",
                "swift_worker_binary",
            ),
        ],
        decls = [
            build_decls.new(
                "swift_worker_binary",
                name = "update",
                attrs = dicts.add(common_attrs, {"extra_args": update_args}),
            ),
            build_decls.new(
                "swift_worker_binary",
                name = "resolve",
                attrs = dicts.add(common_attrs, {"extra_args": resolve_args}),
            ),
        ],
    )

def _build_file(
        slices,
        package_path,
        swift_label,
        flags,
        patch_specs,
        patch_files):
    """Returns the v2 BUILD file with `swift_package_tool_rule` targets.

    Args:
        slices: A `list` of slice `struct` values as described by
            `swift_package_tool_args.render`.
        package_path: The workspace-relative path to `Package.swift`.
        swift_label: The `Package.swift` label passed as `--swift-label`.
        flags: The `key=value\\n` `string` from `staleness.render_flags`.
        patch_specs: A `dict` mapping a package identity to a `struct` with
            `files` (a `list` of canonical patch label strings) and `args`.
        patch_files: A `list` of canonical label strings for every patch
            file, so that `$(rootpath ...)` resolves in the generated targets.

    Returns:
        A `struct` as returned by `build_files.new`.
    """
    decls = []
    for cmd in _V2_CMDS:
        attrs = {
            "args": swift_package_tool_args.to_expr(
                swift_package_tool_args.render(
                    cmd = cmd,
                    package_path = package_path,
                    swift_label = swift_label,
                    slices = slices,
                    flags = flags,
                    patch_specs = patch_specs,
                ),
            ),
            "visibility": ["//visibility:public"],
        }
        if patch_files:
            attrs["data"] = patch_files
        decls.append(
            build_decls.new("swift_package_tool_rule", name = cmd, attrs = attrs),
        )
    return build_files.new(
        load_stmts = [
            load_statements.new(
                "@rules_swift_package_manager//swiftpkg/internal:swift_package_tool_rule.bzl",
                "swift_package_tool_rule",
            ),
        ],
        decls = decls,
    )

def _require(d, key, what):
    if key not in d:
        fail("Expected key '{key}' in {what}: {d}".format(
            key = key,
            what = what,
            d = json.encode(d),
        ))
    return d[key]

def _build_file_from_attr(attr):
    """Decodes the v2 JSON attributes and returns the v2 BUILD file.

    Args:
        attr: The repository rule attributes (`repository_ctx.attr`).

    Returns:
        A `struct` as returned by `build_files.new`.
    """
    slices = [
        struct(**{
            key: _require(s, key, "a slices entry")
            for key in ["config", "config_value", "dir", "package_value"]
        })
        for s in json.decode(attr.slices)
    ]
    patch_files = [str(f) for f in attr.patch_files]
    known_files = {f: None for f in patch_files}
    patch_specs = {}
    for identity, spec in json.decode(attr.patch_specs or "{}").items():
        what = "the patch_specs entry for '{}'".format(identity)
        files = _require(spec, "files", what)
        for f in files:
            if f not in known_files:
                fail("""\
The patch file '{f}' for '{identity}' is not in patch_files: {known}\
""".format(f = f, identity = identity, known = patch_files))
        patch_specs[identity] = struct(
            files = files,
            args = _require(spec, "args", what),
        )
    return _build_file(
        slices = slices,
        package_path = attr.package_path,
        swift_label = attr.swift_label,
        flags = attr.flags,
        patch_specs = patch_specs,
        patch_files = patch_files,
    )

def _swift_package_tool_repo_impl(repository_ctx):
    if repository_ctx.attr.slices:
        # The netrc and registries paths travel in `flags`; the tool
        # resolves them against the workspace. The v1 `env` is ignored.
        build_files.write(
            repository_ctx,
            _build_file_from_attr(repository_ctx.attr),
            "",
        )
        return

    data = []

    if repository_ctx.attr.netrc:
        repository_utils.copy(
            repository_ctx,
            repository_ctx.attr.netrc,
            ".netrc",
        )
        data.append(":.netrc")

    if repository_ctx.attr.registries:
        repository_utils.copy(
            repository_ctx,
            repository_ctx.attr.registries,
            "registries.json",
        )
        data.append(":registries.json")

    build_files.write(
        repository_ctx,
        _v1_build_file(repository_ctx.attr, data),
        "",
    )

swift_package_tool_repo = repository_rule(
    implementation = _swift_package_tool_repo_impl,
    attrs = dicts.add(
        repo_rules.env_attr,
        {
            "flags": attr.string(
                doc = """\
v2: the `key=value\\n` flags as rendered by `staleness.render_flags`. The \
netrc and registries paths travel here as workspace-relative paths.\
""",
            ),
            "package": attr.string(
                doc = """\
The relative path to the `Package.swift` file to operate on. Ignored when \
`slices` is set.\
""",
                mandatory = True,
            ),
            "package_path": attr.string(
                doc = "v2: the workspace-relative path to `Package.swift`.",
            ),
            "patch_files": attr.label_list(
                allow_files = True,
                doc = """\
v2: every patch file referenced in `patch_specs`, so that the generated \
targets list them in `data`.\
""",
            ),
            "patch_specs": attr.string(
                doc = """\
v2: a JSON object mapping a package identity to \
`{"files": [<label string>], "args": [<patch arg>]}`.\
""",
            ),
            "slices": attr.string(
                doc = """\
v2: a JSON list of `{config, config_value, dir, package_value}` objects. \
When set, the rule generates the v2 `resolve`, `update` and `cache` targets \
and ignores the v1 `env`, `netrc` and `registries` attributes.\
""",
            ),
            "swift_label": attr.string(
                doc = "v2: the `Package.swift` label passed as `--swift-label`.",
            ),
        },
        swift_package_tool_attrs.swift_package_tool_config,
        swift_package_tool_attrs.swift_package_registry,
    ),
    doc = """\
Declares a `@swift_package` repository for using the `swift_worker_binary` \
targets.\
""",
)

swift_package_tool_repo_lib = struct(
    build_file = _build_file,
    build_file_from_attr = _build_file_from_attr,
    v1_build_file = _v1_build_file,
)
