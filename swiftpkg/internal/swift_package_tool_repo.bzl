"""Defines the `swift_package_tool_repo` repository rule.

The rule generates `swift_package_tool_rule` targets named `resolve`, `update`
and `cache` that run `swift_deps_tool`.
"""

load("//swiftpkg/internal:build_decls.bzl", "build_decls")
load("//swiftpkg/internal:build_files.bzl", "build_files")
load("//swiftpkg/internal:load_statements.bzl", "load_statements")
load("//swiftpkg/internal:swift_package_tool_args.bzl", "swift_package_tool_args")

_CMDS = ["resolve", "update", "cache"]

def _build_file(
        slices,
        package_path,
        swift_label,
        flags,
        patch_specs,
        patch_files):
    """Returns the BUILD file with `swift_package_tool_rule` targets.

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
    for cmd in _CMDS:
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
    """Decodes the JSON attributes and returns the BUILD file.

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
    # The netrc and registries paths travel in `flags`; the tool resolves
    # them against the workspace.
    build_files.write(
        repository_ctx,
        _build_file_from_attr(repository_ctx.attr),
        "",
    )

swift_package_tool_repo = repository_rule(
    implementation = _swift_package_tool_repo_impl,
    attrs = {
        "flags": attr.string(
            doc = """\
The `key=value\\n` flags as rendered by `staleness.render_flags`. The netrc \
and registries paths come from the root slices' `from_package` tags and \
travel here as workspace-relative paths.\
""",
        ),
        "package_path": attr.string(
            doc = "The workspace-relative path to `Package.swift`.",
            mandatory = True,
        ),
        "patch_files": attr.label_list(
            allow_files = True,
            doc = """\
Every patch file referenced in `patch_specs`, so that the generated targets \
list them in `data`.\
""",
        ),
        "patch_specs": attr.string(
            doc = """\
A JSON object mapping a package identity to \
`{"files": [<label string>], "args": [<patch arg>]}`.\
""",
        ),
        "slices": attr.string(
            doc = """\
A JSON list of `{config, config_value, dir, package_value}` objects, one per \
root slice.\
""",
            mandatory = True,
        ),
        "swift_label": attr.string(
            doc = "The `Package.swift` label passed as `--swift-label`.",
            mandatory = True,
        ),
    },
    doc = """\
Declares the `@swift_package` repository with the `resolve`, `update` and \
`cache` targets.\
""",
)

swift_package_tool_repo_lib = struct(
    build_file = _build_file,
    build_file_from_attr = _build_file_from_attr,
)
