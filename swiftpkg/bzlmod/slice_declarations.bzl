"""Collects and evaluates the v2 slices of the `swift_deps` extension.

A v2 `from_package` tag (one with `dump_manifests`) describes one slice: one
resolution of a `Package.swift` for one config. `collect` turns the tags into
slices. `evaluate` decides whether a slice's `swift_deps_cache` is fresh and
lists the packages it contributes.

Extension evaluation is all or nothing, so nothing here calls `fail()` for a
missing or stale cache. A stale slice still lists every package name it knows
so that the root `use_repo` keeps working. Only user errors fail: a tag
without `config` or `resolved`, an inconsistent tag, two root slices with the
same config, and a registry pin in a fresh slice.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//swiftpkg/internal:bazel_repo_names.bzl", "bazel_repo_names")
load("//swiftpkg/internal:manifest_files.bzl", "manifest_files")
load("//swiftpkg/internal:manifest_shapes.bzl", "manifest_shapes")
load("//swiftpkg/internal:pkginfo_dependencies.bzl", "pkginfo_dependencies")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:slice_messages.bzl", "slice_messages")
load("//swiftpkg/internal:slices.bzl", "slices")
load("//swiftpkg/internal:staleness.bzl", "staleness")

_MAIN = "_main"
_REGISTRY_ISSUE = "https://github.com/cgrindel/rules_swift_package_manager/issues/2699"
_DO_WHILE_RANGE = range(1000)

def _error(msg):
    return struct(error = msg, result = None)

def _ok(result):
    return struct(error = None, result = result)

# MARK: - Collect

def _collect_or_error(modules, is_dev_dependency):
    """Builds a slice for every v2 `from_package` tag.

    Args:
        modules: The value of `module_ctx.modules`.
        is_dev_dependency: `module_ctx.is_dev_dependency`.

    Returns:
        A `struct(error, result)`. `result` is a `list` of slices in module
        and tag order.
    """
    result = []
    root_dirs_by_config = {}
    for mod in modules:
        for tag in mod.tags.from_package:
            if not tag.dump_manifests:
                continue
            for attr in ["config", "resolved"]:
                if getattr(tag, attr) == None:
                    return _error((
                        "from_package `{swift}`{where}: `{attr}` is required " +
                        "when `dump_manifests` is set"
                    ).format(
                        swift = str(tag.swift),
                        where = (
                            " (slice `{}`)".format(tag.resolved.package) if tag.resolved != None else ""
                        ),
                        attr = attr,
                    ))
            slice = slices.new(
                config = tag.config,
                swift = tag.swift,
                resolved = tag.resolved,
                dump_manifests = tag.dump_manifests,
                desc_manifests = tag.desc_manifests,
                is_root = mod.is_root,
                is_dev = is_dev_dependency(tag),
            )
            err = slices.validate(slice)
            if err != None:
                return _error(err)
            if slice.is_root:
                other = root_dirs_by_config.get(slice.config)
                if other != None:
                    return _error((
                        "slices `{a}` and `{b}` have the same config " +
                        "`{config}`; each slice of the root module needs its " +
                        "own config"
                    ).format(a = other, b = slice.dir, config = slice.config))
                root_dirs_by_config[slice.config] = slice.dir
            result.append(slice)
    return _ok(result)

def _collect(module_ctx):
    """Builds a slice for every v2 `from_package` tag of every module.

    Args:
        module_ctx: A `module_ctx`.

    Returns:
        A `list` of slices from `slices.new`, in module and tag order.
    """
    collected = _collect_or_error(
        module_ctx.modules,
        module_ctx.is_dev_dependency,
    )
    if collected.error != None:
        fail(collected.error)
    return collected.result

# MARK: - Pins

def _pin_maps(resolved_map):
    """The well-formed pin `dict` values of a decoded `Package.resolved`.

    A malformed pin is skipped rather than failing the extension.
    """
    if type(resolved_map) != "dict":
        return []
    pins = resolved_map.get("pins")
    if type(pins) != "list":
        return []
    return [
        pin_map
        for pin_map in pins
        if (type(pin_map) == "dict" and
            type(pin_map.get("identity")) == "string" and
            type(pin_map.get("kind")) == "string" and
            type(pin_map.get("location")) == "string" and
            type(pin_map.get("state")) == "dict")
    ]

def _pins(resolved_map):
    """The well-formed pins of a decoded `Package.resolved`, as pin structs."""
    return [
        pkginfos.new_pin_from_resolved_dep_map(pin_map)
        for pin_map in _pin_maps(resolved_map)
    ]

def _pin_kind(pin):
    if pin.kind == "registry":
        return "registry"
    if pin.kind in ["remoteSourceControl", "localSourceControl"]:
        return "source_control"
    return "unknown"

def _pin_key(pin):
    if pin.kind == "registry":
        return "registry:{}@{}".format(pin.identity, pin.state.version)
    return "{}@{}".format(pin.location, pin.state.revision)

def _stale_pkgs(slice, resolved_map):
    """The packages a stale slice contributes, by name only.

    Args:
        slice: A slice from `slices.new`.
        resolved_map: The decoded live `Package.resolved`, or `None`.

    Returns:
        A `dict` of identity to `struct(kind, pin_key)`.
    """
    pkgs = {
        identity: struct(kind = "unknown", pin_key = None)
        for identity in slice.identities
        if identity != _MAIN
    }
    for pin in _pins(resolved_map):
        pkgs[pin.identity] = struct(kind = _pin_kind(pin), pin_key = _pin_key(pin))
    return pkgs

# MARK: - Patches

def _patch_files_by_identity(module_ctx, slice, config_pkgs):
    """Maps the patch files of `configure_package` tags to identities.

    A tag's name matches, in order: an identity equal to the lowercased name,
    an identity whose repository name is the name, or a dependency name in
    the cached root `dump.json`. A tag that matches nothing is ignored, as v1
    ignores unknown `configure_package` names.

    Args:
        module_ctx: A `module_ctx`.
        slice: A slice from `slices.new`.
        config_pkgs: A `dict` of name to `configure_package` tag.

    Returns:
        A `dict` of identity to `list` of patch `Label`.
    """
    by_repo_name = {
        bazel_repo_names.from_identity(identity): identity
        for identity in slice.identities
    }
    by_dep_name = None
    result = {}
    for name in sorted(config_pkgs.keys()):
        tag = config_pkgs[name]
        if not tag.patches:
            continue
        identity = None
        if name.lower() in slice.identities:
            identity = name.lower()
        elif name in by_repo_name:
            identity = by_repo_name[name]
        else:
            if by_dep_name == None:
                dump = manifest_files.read_json(
                    module_ctx,
                    slice.dump_manifests[_MAIN],
                )
                by_dep_name = {}
                if type(dump) == "dict":
                    by_dep_name = pkginfos.dependency_identity_by_name(dump)
            identity = by_dep_name.get(pkginfo_dependencies.normalize_name(name))
        if identity == None:
            continue
        result.setdefault(identity, []).extend(tag.patches)
    return result

# MARK: - Evaluate

def _bazel_workspace_root(swift, abs_swift):
    """The directory that `local_swift_package` resolves relative paths against.

    It is derived from the `swift` label as v1 does, so it is right even when
    `Package.swift` lives in a subdirectory.

    Args:
        swift: The `Label` of the `Package.swift`.
        abs_swift: The absolute path of the `Package.swift` as a `string`.

    Returns:
        The absolute workspace root as a `string`.
    """
    suffix = "/" + paths.join(swift.package, swift.name)
    if abs_swift.endswith(suffix):
        return abs_swift[:-len(suffix)]
    return paths.dirname(abs_swift)

def _read_manifest(module_ctx, manifests, identity, basename):
    """Reads one cached manifest of a slice.

    Returns:
        A `struct(label, text, value, reason)`. `reason` is `None` when the
        manifest is listed, exists, and decodes to a JSON object.
    """
    label = manifests.get(identity)
    if label == None:
        return struct(
            label = None,
            text = None,
            value = None,
            reason = "{}/{}: not listed in the slice".format(identity, basename),
        )
    text = manifest_files.read_text(module_ctx, label)
    reason = None
    value = None
    if text == None:
        reason = "{}/{}: missing cached copy".format(identity, basename)
    else:
        value = json.decode(text, default = None)
        if type(value) != "dict":
            reason = "{}/{}: not valid JSON".format(identity, basename)
    return struct(label = label, text = text, value = value, reason = reason)

def _read_manifests(module_ctx, slice, identity):
    dump = _read_manifest(module_ctx, slice.dump_manifests, identity, "dump.json")
    desc = _read_manifest(module_ctx, slice.desc_manifests, identity, "desc.json")
    reasons = [m.reason for m in [dump, desc] if m.reason != None]
    return struct(dump = dump, desc = desc, reasons = reasons)

def _read_parseable_manifests(module_ctx, slice, identity):
    """Like `_read_manifests`, but also checks the shape the parser needs."""
    m = _read_manifests(module_ctx, slice, identity)
    if m.reasons:
        return m
    err = manifest_shapes.check(m.dump.value, m.desc.value)
    if err == None:
        return m
    return struct(
        dump = m.dump,
        desc = m.desc,
        reasons = ["{}/dump.json: {}".format(identity, err)],
    )

def _fresh_pkgs(module_ctx, slice, directory, bazel_workspace_root, resolved_map):
    """Builds the packages of a slice whose staleness inputs are fresh.

    The repo set is computed as v1 does: the direct deps of the root package,
    every pin in `Package.resolved`, and the transitive local packages. All
    manifests come from the cache.

    Returns:
        A `struct(reasons, pkgs, pkg_info)`. A non-empty `reasons` means the
        cache does not cover the repo set after all, so the slice is stale.
    """
    main = _read_parseable_manifests(module_ctx, slice, _MAIN)
    if main.reasons:
        return struct(reasons = main.reasons, pkgs = None, pkg_info = None)

    pkg_info = pkginfos.new_from_manifests(
        module_ctx,
        directory = directory,
        dump_manifest = main.dump.value,
        desc_manifest = main.desc.value,
        # Only the pins that `_pins` accepts, so a malformed one cannot fail
        # the parser.
        resolved_pkg_map = {"pins": _pin_maps(resolved_map)},
        collect_src_info = False,
    )

    # Direct deps, then every pin not already present.
    all_deps_by_id = {dep.identity: dep for dep in pkg_info.dependencies}
    for pin in _pins(resolved_map):
        if pin.identity in all_deps_by_id:
            continue
        all_deps_by_id[pin.identity] = pkginfos.new_dependency(
            identity = pin.identity,
            # Just use the identity for the name as we just need this to set
            # up the repositories.
            name = pin.identity,
            source_control = pkginfos.new_source_control(pin = pin),
        )

    # A local package can depend on other local packages, so walk them all.
    # Remote deps of local packages are already in `Package.resolved`.
    manifests_by_id = {}
    to_process = [dep for dep in all_deps_by_id.values() if dep.file_system]
    for _ in _DO_WHILE_RANGE:
        if not to_process:
            break
        processing = to_process
        to_process = []
        for dep in processing:
            m = _read_parseable_manifests(module_ctx, slice, dep.identity)
            manifests_by_id[dep.identity] = m
            if m.reasons:
                continue
            dep_pkg_info = pkginfos.new_from_manifests(
                module_ctx,
                directory = dep.file_system.path,
                dump_manifest = m.dump.value,
                desc_manifest = m.desc.value,
                collect_src_info = False,
                source_directory = dep.file_system.path,
            )
            for fs_dep in dep_pkg_info.dependencies:
                if fs_dep.file_system and fs_dep.identity not in all_deps_by_id:
                    all_deps_by_id[fs_dep.identity] = fs_dep
                    to_process.append(fs_dep)
    if to_process:
        fail("Expected no more items to process, but found some.")

    reasons = []
    pkgs = {}
    for identity in sorted(all_deps_by_id.keys()):
        dep = all_deps_by_id[identity]
        m = manifests_by_id.get(identity)
        if m == None:
            m = _read_manifests(module_ctx, slice, identity)
        if m.reasons:
            reasons.extend(m.reasons)
            continue
        local_path = None
        if dep.file_system:
            kind = "local"
            local_path = repository_utils.relativize_repo_path(
                dep.file_system.path,
                bazel_workspace_root,
            )
            pin_key = "path:" + local_path
        elif (dep.source_control and dep.source_control.pin.state and
              dep.source_control.pin.state.revision):
            kind = "source_control"
            pin_key = _pin_key(dep.source_control.pin)
        else:
            reasons.append("{}: not pinned in Package.resolved".format(identity))
            continue
        pkgs[identity] = struct(
            kind = kind,
            pin_key = pin_key,
            dump_text = m.dump.text,
            desc_text = m.desc.text,
            dump_label = m.dump.label,
            desc_label = m.desc.label,
            local_path = local_path,
            dep = dep,
        )
    return struct(reasons = reasons, pkgs = pkgs, pkg_info = pkg_info)

def _new_evaluated(slice, reasons, pkgs, pkg_info = None, module_aliases_by_id = {}):
    return struct(
        slice = slice,
        stale = len(reasons) > 0,
        reasons = reasons,
        pkgs = pkgs,
        pkg_info = pkg_info,
        module_aliases_by_id = module_aliases_by_id,
    )

def _evaluate_or_error(
        module_ctx,
        slice,
        config_swift_package,
        config_pkgs,
        directory,
        bazel_workspace_root,
        collect_inputs = staleness.collect):
    """Evaluates a slice, returning an error instead of failing.

    Args:
        module_ctx: A `module_ctx`.
        slice: A slice from `slices.new`.
        config_swift_package: A `configure_swift_package` tag or `None`.
        config_pkgs: A `dict` of name to `configure_package` tag.
        directory: The absolute directory of `slice.swift` as a `string`.
        bazel_workspace_root: The absolute workspace root as a `string`.
        collect_inputs: `staleness.collect` or a stand-in.

    Returns:
        A `struct(error, result)`. `result` is as `slice_declarations.evaluate`
        returns.
    """
    patch_files_by_identity = _patch_files_by_identity(
        module_ctx,
        slice,
        config_pkgs,
    )
    verdict = staleness.evaluate(collect_inputs(
        module_ctx,
        slice,
        config_swift_package,
        patch_files_by_identity,
    ))

    # The live `Package.resolved` is absent for a package with no remote deps.
    resolved_text = manifest_files.read_text(module_ctx, slice.resolved)
    resolved_map = {}
    if resolved_text != None:
        resolved_map = json.decode(resolved_text, default = None)

    if verdict.stale:
        return _ok(_new_evaluated(
            slice,
            verdict.reasons,
            _stale_pkgs(slice, resolved_map),
        ))

    if type(resolved_map) != "dict":
        return _ok(_new_evaluated(
            slice,
            ["{}/Package.resolved: not valid JSON".format(_MAIN)],
            _stale_pkgs(slice, None),
        ))

    for pin in _pins(resolved_map):
        if pin.kind == "registry":
            return _error((
                "registry package `{identity}` is not supported by v2 yet; " +
                "see {url}"
            ).format(identity = pin.identity, url = _REGISTRY_ISSUE))

    fresh = _fresh_pkgs(
        module_ctx,
        slice,
        directory,
        bazel_workspace_root,
        resolved_map,
    )
    if fresh.reasons:
        return _ok(_new_evaluated(
            slice,
            fresh.reasons,
            _stale_pkgs(slice, resolved_map),
        ))
    return _ok(_new_evaluated(
        slice,
        [],
        fresh.pkgs,
        pkg_info = fresh.pkg_info,
        module_aliases_by_id = pkginfo_dependencies.module_aliases_by_identity(
            fresh.pkg_info,
        ),
    ))

def _stale_warning(slice, reasons):
    return "WARNING: {msg}. Reasons: {reasons}".format(
        msg = slice_messages.stale(slice.dir, slice.config),
        reasons = "; ".join(reasons),
    )

def _evaluate(module_ctx, slice, config_swift_package, config_pkgs):
    """Decides whether a slice is fresh and lists its packages.

    Args:
        module_ctx: A `module_ctx`.
        slice: A slice from `slices.new`.
        config_swift_package: A `configure_swift_package` tag or `None`.
        config_pkgs: A `dict` of name to `configure_package` tag.

    Returns:
        A `struct` with:
        - `slice`: the slice.
        - `stale`: whether the cache is stale.
        - `reasons`: a `list` of `string`, empty when fresh.
        - `pkgs`: a `dict` of identity (never `_main`) to an entry. A fresh
          entry is `struct(kind, pin_key, dump_text, desc_text, dump_label,
          desc_label, local_path, dep)`, where `kind` is `source_control` or
          `local` and `dep` is the `pkginfos.new_dependency` struct. A stale
          entry is `struct(kind, pin_key)`, where `kind` is `source_control`,
          `registry`, or `unknown`, and `pin_key` is `None` for `unknown`.
        - `pkg_info`: the root package info, or `None` when stale.
        - `module_aliases_by_id`: the root's SE-0339 aliases by identity, or
          `{}` when stale.
    """
    abs_swift = str(module_ctx.path(slice.swift))
    evaluated = _evaluate_or_error(
        module_ctx,
        slice,
        config_swift_package,
        config_pkgs,
        directory = paths.dirname(abs_swift),
        bazel_workspace_root = _bazel_workspace_root(slice.swift, abs_swift),
    )
    if evaluated.error != None:
        fail(evaluated.error)
    if evaluated.result.stale:
        # buildifier: disable=print
        print(_stale_warning(slice, evaluated.result.reasons))
    return evaluated.result

def _to_merge_entry(evaluated):
    """Returns the `slice_merge.merge` input for an evaluated slice.

    Args:
        evaluated: A `struct` as returned by `slice_declarations.evaluate`.

    Returns:
        A `struct(config, dir, stale, pkgs)`.
    """
    return struct(
        config = evaluated.slice.config,
        dir = evaluated.slice.dir,
        stale = evaluated.stale,
        pkgs = evaluated.pkgs,
    )

# MARK: - Declare

def _declare(
        module_ctx,
        evaluated,
        config_pkgs,
        config_swift_package,
        target_mods_by_repo,
        matched_target_mod_repos,
        available_target_mod_repos,
        inference_config):
    """Declares the repositories of the evaluated slices.

    Not implemented yet (Task 3.4).

    Args:
        module_ctx: A `module_ctx`.
        evaluated: A `list` of `slice_declarations.evaluate` results.
        config_pkgs: A `dict` of name to `configure_package` tag.
        config_swift_package: A `configure_swift_package` tag or `None`.
        target_mods_by_repo: See `_declare_pkgs_from_package`.
        matched_target_mod_repos: See `_declare_pkgs_from_package`.
        available_target_mod_repos: See `_declare_pkgs_from_package`.
        inference_config: See `_declare_pkgs_from_package`.

    Returns:
        A `struct(direct, direct_dev)` of repository names.
    """

    # buildifier: disable=unused-variable
    _ignore = (
        module_ctx,
        evaluated,
        config_pkgs,
        config_swift_package,
        target_mods_by_repo,
        matched_target_mod_repos,
        available_target_mod_repos,
        inference_config,
    )
    fail("v2 declaration is not implemented yet")

slice_declarations = struct(
    collect = _collect,
    declare = _declare,
    evaluate = _evaluate,
    to_merge_entry = _to_merge_entry,
)

slice_declarations_testing = struct(
    bazel_workspace_root = _bazel_workspace_root,
    collect_or_error = _collect_or_error,
    evaluate_or_error = _evaluate_or_error,
    patch_files_by_identity = _patch_files_by_identity,
    stale_warning = _stale_warning,
)
