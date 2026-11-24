"""Implementation for the `swift_package_aliases` repository rule."""

load(":build_decls.bzl", "build_decls")
load(":build_files.bzl", "build_files")
load(":load_statements.bzl", "load_statements")
load(":slice_messages.bzl", "slice_messages")
load(":starlark_codegen.bzl", scg = "starlark_codegen")

_STALE_NAME = "_stale"

def _build_file(names, branches, stale_message):
    """Creates the alias repository's root build file.

    Args:
        names: A `list` of target names to alias.
        branches: A `dict` mapping a config label `string` to the name of the
            package repository that serves it, or `""` for a stale slice.
        stale_message: The message reported when a stale branch is selected.

    Returns:
        A `struct` as returned by `build_files.new`.
    """
    configs = sorted(branches.keys())
    no_match_error = slice_messages.no_match(configs)
    decls = []
    for name in sorted(names):
        if name == _STALE_NAME:
            continue
        select_dict = {}
        for config in configs:
            repo = branches[config]
            if repo:
                select_dict[config] = "@{repo}//:{name}".format(
                    repo = repo,
                    name = name,
                )
            else:
                select_dict[config] = ":" + _STALE_NAME
        decls.append(build_decls.new(
            "alias",
            name,
            attrs = {
                "actual": scg.new_fn_call(
                    "select",
                    select_dict,
                    no_match_error = no_match_error,
                ),
                "visibility": ["//visibility:public"],
            },
        ))

    load_stmts = []
    if "" in branches.values():
        load_stmts.append(load_statements.new(
            "@rules_swift_package_manager//swiftpkg:build_defs.bzl",
            "swift_package_stale",
        ))
        decls.append(build_decls.new(
            "swift_package_stale",
            _STALE_NAME,
            attrs = {"message": stale_message},
        ))

    return build_files.new(load_stmts = load_stmts, decls = decls)

def _swift_package_aliases_impl(repository_ctx):
    # Sibling repositories declared by the same extension are not visible by
    # apparent name from this .bzl file, so address them by canonical name.
    # The canonical names share a prefix with this repository's canonical name.
    apparent_name = getattr(
        repository_ctx,
        "original_name",
        repository_ctx.attr.name,
    )
    canonical_name = repository_ctx.name
    if not canonical_name.endswith(apparent_name):
        fail("""\
Expected the canonical repository name '{canonical}' to end with the \
repository name '{name}'.\
""".format(canonical = canonical_name, name = apparent_name))
    canonical_prefix = canonical_name[:len(canonical_name) - len(apparent_name)]

    names = {}
    for repo in sorted({r: None for r in repository_ctx.attr.branches.values() if r}):
        targets_json = repository_ctx.read(Label(
            "@@{prefix}{repo}//:targets.json".format(
                prefix = canonical_prefix,
                repo = repo,
            ),
        ))
        for name in json.decode(targets_json)["targets"]:
            names[name] = None

    bld_file = _build_file(
        names = names.keys(),
        branches = repository_ctx.attr.branches,
        stale_message = repository_ctx.attr.stale_message,
    )
    build_files.write(repository_ctx, bld_file, "")

swift_package_aliases = repository_rule(
    implementation = _swift_package_aliases_impl,
    attrs = {
        "branches": attr.string_dict(
            doc = """\
A `dict` mapping a config label to the name of the package repository that \
serves it. An empty value marks a stale slice.\
""",
            mandatory = True,
        ),
        "stale_message": attr.string(
            doc = "The message reported when a stale branch is selected.",
            default = "",
        ),
    },
    doc = """\
Declares `alias` targets that select a package repository per slice config.

Each target named in the package repositories' `targets.json` files gets an \
`alias` whose `actual` selects the matching repository's target. A package \
repository that uses a custom `build_file` lists no targets, so it \
contributes no aliases.\
""",
)

swift_package_aliases_lib = struct(
    build_file = _build_file,
)
