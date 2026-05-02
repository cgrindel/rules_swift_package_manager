"""Module for creating a module index context for a package info."""

load(":manual_target_deps.bzl", "manual_target_deps")
load(":pkginfos.bzl", "pkginfos")
load(":repository_utils.bzl", "repository_utils")

def _read(
        repository_ctx,
        repo_dir,
        env,
        cached_json_directory,
        dump_manifest = None,
        desc_manifest = None,
        resolved_pkg_map = None,
        registries_directory = None,
        replace_scm_with_registry = False,
        target_deps = {}):
    pkg_info = pkginfos.get(
        repository_ctx = repository_ctx,
        directory = repo_dir,
        env = env,
        cached_json_directory = cached_json_directory,
        dump_manifest = dump_manifest,
        desc_manifest = desc_manifest,
        resolved_pkg_map = resolved_pkg_map,
        registries_directory = registries_directory,
        replace_scm_with_registry = replace_scm_with_registry,
    )
    return _new(
        pkg_info = pkg_info,
        repo_name = repository_utils.package_name(repository_ctx),
        target_deps = target_deps,
    )

def _new(pkg_info, repo_name, target_deps = {}):
    manual_target_deps.validate(pkg_info, target_deps)
    return struct(
        pkg_info = pkg_info,
        repo_name = repo_name,
        target_deps = target_deps,
    )

def _read_cached_manifests(repository_ctx):
    """Decode cached_dump_manifest and cached_desc_manifest when set.

    The two attributes are paired: setting only one is a hard error
    (the cache mechanism is meaningless without both). When unset, the
    caller falls back to running `swift package dump-package` /
    `describe` against the on-disk source.

    Args:
        repository_ctx: A `repository_ctx` whose attrs may include
            `cached_dump_manifest` and `cached_desc_manifest`.

    Returns:
        A `(dump_manifest, desc_manifest)` tuple. Both are `None` when
        neither attribute is set; both are populated dicts when both
        are set.
    """
    attr = repository_ctx.attr
    dump_label = getattr(attr, "cached_dump_manifest", None)
    desc_label = getattr(attr, "cached_desc_manifest", None)
    has_dump = bool(dump_label)
    has_desc = bool(desc_label)
    if has_dump != has_desc:
        fail("""\
`cached_dump_manifest` and `cached_desc_manifest` must be provided \
together; got cached_dump_manifest={}, cached_desc_manifest={}.\
""".format(dump_label, desc_label))
    if not has_dump:
        return (None, None)

    # Cached JSON encodes sibling local-package paths with the
    # `{{WORKSPACE_ROOT}}` token so the cache stays portable across
    # checkouts. Substitute it back to the consumer's workspace before
    # parsing so downstream code sees absolute paths.
    ws_root = str(repository_ctx.workspace_root)
    dump_text = repository_ctx.read(dump_label).replace(
        "{{WORKSPACE_ROOT}}",
        ws_root,
    )
    desc_text = repository_ctx.read(desc_label).replace(
        "{{WORKSPACE_ROOT}}",
        ws_root,
    )
    dump = json.decode(dump_text)
    desc = json.decode(desc_text)
    return (dump, desc)

pkg_ctxs = struct(
    new = _new,
    read = _read,
    read_cached_manifests = _read_cached_manifests,
)
