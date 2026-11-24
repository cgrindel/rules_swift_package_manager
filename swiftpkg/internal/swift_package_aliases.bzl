"""Implementation for the `swift_package_aliases` repository rule."""

load(":build_decls.bzl", "build_decls")
load(":build_files.bzl", "build_files")
load(":load_statements.bzl", "load_statements")
load(":slice_messages.bzl", "slice_messages")
load(":starlark_codegen.bzl", scg = "starlark_codegen")

_STALE_PREFIX = "_stale_"

def _build_file(names, branches, stale_messages):
    """Creates the alias repository's root build file.

    Args:
        names: A `list` of target names to alias.
        branches: A `dict` mapping a config label `string` to the name of the
            package repository that serves it, or `""` when no repository
            serves that config (a stale slice or a slice that lacks the
            package).
        stale_messages: A `dict` mapping each config whose branch is `""` to
            the message reported when that branch is selected.

    Returns:
        A `struct` as returned by `build_files.new`.
    """
    configs = sorted(branches.keys())
    no_match_error = slice_messages.no_match(configs)

    # One `swift_package_stale` target per empty branch, numbered from 1 in
    # sorted-config order, so each config reports its own message.
    stale_targets = {}
    for config in configs:
        if branches[config]:
            continue
        message = stale_messages.get(config)
        if not message:
            fail("Missing stale message for config `{}`.".format(config))
        stale_targets[config] = struct(
            name = _STALE_PREFIX + str(len(stale_targets) + 1),
            message = message,
        )
    stale_names = {t.name: None for t in stale_targets.values()}

    decls = []
    for name in sorted(names):
        if name in stale_names:
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
                select_dict[config] = ":" + stale_targets[config].name
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
    if stale_targets:
        load_stmts.append(load_statements.new(
            "@rules_swift_package_manager//swiftpkg:build_defs.bzl",
            "swift_package_stale",
        ))
        for config in configs:
            target = stale_targets.get(config)
            if target == None:
                continue
            decls.append(build_decls.new(
                "swift_package_stale",
                target.name,
                attrs = {"message": target.message},
            ))

    return build_files.new(load_stmts = load_stmts, decls = decls)

def _swift_package_aliases_impl(repository_ctx):
    # Sibling repositories declared by the same extension are not visible by
    # apparent name from this .bzl file, so address them by canonical name.
    # The canonical names share a prefix with this repository's canonical name.
    if not hasattr(repository_ctx, "original_name"):
        fail("""\
`swift_package_aliases` needs `repository_ctx.original_name`, which this \
Bazel version does not provide.\
""")
    apparent_name = repository_ctx.original_name
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
            "@@{prefix}{repo}//:rspm_targets.json".format(
                prefix = canonical_prefix,
                repo = repo,
            ),
        ))
        for name in json.decode(targets_json)["targets"]:
            names[name] = None

    bld_file = _build_file(
        names = names.keys(),
        branches = repository_ctx.attr.branches,
        stale_messages = repository_ctx.attr.stale_messages,
    )
    build_files.write(repository_ctx, bld_file, "")

swift_package_aliases = repository_rule(
    implementation = _swift_package_aliases_impl,
    attrs = {
        "branches": attr.string_dict(
            doc = """\
A `dict` mapping a config label to the name of the package repository that \
serves it. An empty value marks a config that no repository serves: its slice \
is stale or lacks the package.\
""",
            mandatory = True,
        ),
        "stale_messages": attr.string_dict(
            doc = """\
A `dict` mapping each config whose `branches` value is empty to the message \
reported when that branch is selected. Required for every empty branch.\
""",
        ),
    },
    doc = """\
Declares `alias` targets that select a package repository per slice config.

Each target named in the package repositories' `rspm_targets.json` files gets an \
`alias` whose `actual` selects the matching repository's target. A package \
repository that uses a custom `build_file` lists no targets, so it \
contributes no aliases.\
""",
)

swift_package_aliases_lib = struct(
    build_file = _build_file,
)
