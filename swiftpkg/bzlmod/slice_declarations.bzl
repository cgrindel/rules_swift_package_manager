"""Collects and evaluates the v2 slices of the `swift_deps` extension.

A v2 `from_package` tag (one with `config` or `dump_manifests`) describes
one slice: one resolution of a `Package.swift` for one config. `collect` turns
the tags into slices. `evaluate` decides whether a slice's `swift_deps_cache` is fresh and
lists the packages it contributes.

Extension evaluation is all or nothing, so nothing here calls `fail()` for a
missing, stale, or inconsistent cache. A stale slice still lists every package
name it knows so that the root `use_repo` keeps working. Only user errors
fail: a v2 tag in a non-root module, a tag without `config` or `resolved`, two
root slices with the same config, and a registry pin in a fresh slice.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("//swiftpkg/internal:bazel_repo_names.bzl", "bazel_repo_names")
load("//swiftpkg/internal:bazel_target_mods.bzl", "bazel_target_mods")
load("//swiftpkg/internal:local_swift_package.bzl", "local_swift_package")
load("//swiftpkg/internal:manifest_files.bzl", "manifest_files")
load("//swiftpkg/internal:manifest_shapes.bzl", "manifest_shapes")
load("//swiftpkg/internal:pkginfo_dependencies.bzl", "pkginfo_dependencies")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:repository_utils.bzl", "repository_utils")
load("//swiftpkg/internal:slice_merge.bzl", "slice_merge")
load("//swiftpkg/internal:slice_messages.bzl", "slice_messages")
load("//swiftpkg/internal:slices.bzl", "slices")
load("//swiftpkg/internal:stale_swift_package.bzl", "stale_swift_package")
load("//swiftpkg/internal:staleness.bzl", "staleness")
load("//swiftpkg/internal:swift_package.bzl", "swift_package")
load("//swiftpkg/internal:swift_package_aliases.bzl", "swift_package_aliases")
load("//swiftpkg/internal:swift_package_tool_repo.bzl", "swift_package_tool_repo")
load(":swift_deps_common.bzl", "swift_deps_common", "swift_deps_package_repos")

_MAIN = "_main"
_REGISTRY_ISSUE = "https://github.com/cgrindel/rules_swift_package_manager/issues/2699"
_NON_ROOT_ISSUE = "https://github.com/cgrindel/rules_swift_package_manager/issues/2641"
_DO_WHILE_RANGE = range(1000)

def _error(msg):
    return struct(error = msg, result = None)

def _ok(result):
    return struct(error = None, result = result)

# MARK: - Collect

def _collect_or_error(modules, is_dev_dependency):
    """Builds a slice for every v2 `from_package` tag.

    Only the root module may declare v2 tags for now. The committed manifest
    lists are not validated here: `evaluate` marks an inconsistent slice
    stale.

    Args:
        modules: The value of `module_ctx.modules`.
        is_dev_dependency: `module_ctx.is_dev_dependency`.

    Returns:
        A `struct(error, result)`. `result` is a `list` of slices in tag
        order.
    """
    result = []
    root_dirs_by_config = {}
    for mod in modules:
        for tag in mod.tags.from_package:
            if not slices.is_v2_tag(tag):
                continue
            if not mod.is_root:
                return _error((
                    "v2 `from_package` slices are only supported in the " +
                    "root module for now (module `{name}`); see {url}"
                ).format(name = mod.name, url = _NON_ROOT_ISSUE))
            for attr in ["config", "resolved"]:
                if getattr(tag, attr) == None:
                    return _error((
                        "from_package `{swift}`{where}: `{attr}` is required " +
                        "when `config` or `dump_manifests` is set"
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
                netrc = tag.netrc,
                registries = tag.registries,
                make_files_read_only = tag.make_files_read_only,
            )
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
    """Builds a slice for every v2 `from_package` tag of the root module.

    Fails when a non-root module declares a v2 tag.

    Args:
        module_ctx: A `module_ctx`.

    Returns:
        A `list` of slices from `slices.new`, in tag order.
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
        A `dict` of identity to `struct(kind, pin_key, swift_version)`, with
        `swift_version = None`.
    """
    pkgs = {
        identity: struct(kind = "unknown", pin_key = None, swift_version = None)
        for identity in slice.identities
        if identity != _MAIN
    }
    for pin in _pins(resolved_map):
        pkgs[pin.identity] = struct(
            kind = _pin_kind(pin),
            pin_key = _pin_key(pin),
            swift_version = None,
        )
    return pkgs

# MARK: - Patches

def _patch_tags_by_identity(module_ctx, slice, config_pkgs, pinned = []):
    """Maps the `configure_package` tags with patches to identities.

    A tag's name matches, in order: an identity equal to the lowercased name,
    an identity whose repository name is the name, or a dependency name in
    the cached root `dump.json`. A tag that matches nothing is ignored, as v1
    ignores unknown `configure_package` names.

    Args:
        module_ctx: A `module_ctx`.
        slice: A slice from `slices.new`.
        config_pkgs: A `dict` of name to `configure_package` tag.
        pinned: Optional. More identities to match, such as the pins of a
            slice that `init` just wrote and that lists no manifests yet.

    Returns:
        A `dict` of identity to `list` of tags, in sorted name order.
    """
    identities = {i: None for i in slice.identities}
    for identity in pinned:
        identities[identity] = None
    by_repo_name = {
        bazel_repo_names.from_identity(identity): identity
        for identity in identities
    }
    by_dep_name = None
    result = {}
    for name in sorted(config_pkgs.keys()):
        tag = config_pkgs[name]
        if not tag.patches:
            continue
        identity = None
        if name.lower() in identities:
            identity = name.lower()
        elif name in by_repo_name:
            identity = by_repo_name[name]
        else:
            if by_dep_name == None:
                by_dep_name = {}

                # A slice that `init` just wrote lists no manifests yet.
                if _MAIN in slice.dump_manifests:
                    dump = manifest_files.read_json(
                        module_ctx,
                        slice.dump_manifests[_MAIN],
                    )
                    if type(dump) == "dict":
                        by_dep_name = pkginfos.dependency_identity_by_name(dump)
            identity = by_dep_name.get(pkginfo_dependencies.normalize_name(name))
        if identity == None:
            continue
        result.setdefault(identity, []).append(tag)
    return result

def _patch_files_by_identity(module_ctx, slice, config_pkgs):
    """Maps the patch files of `configure_package` tags to identities.

    See `_patch_tags_by_identity` for how a tag's name is matched.

    Args:
        module_ctx: A `module_ctx`.
        slice: A slice from `slices.new`.
        config_pkgs: A `dict` of name to `configure_package` tag.

    Returns:
        A `dict` of identity to `list` of patch `Label`.
    """
    result = {}
    for identity, tags in _patch_tags_by_identity(module_ctx, slice, config_pkgs).items():
        for tag in tags:
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

    # Part of the grouping key: one repository serves only slices cached with
    # the same Swift `major.minor`, the granularity of the build-time version
    # check. Patch versions do not change manifest selection, so a 6.4.2 slice
    # and a 6.4.0 slice with identical manifests share one repository.
    swift_version = manifest_files.read_text(
        module_ctx,
        slices.cache_label(slice, _MAIN, "swift_version.txt"),
    )
    if swift_version != None:
        swift_version = _major_minor(swift_version.strip())

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
            swift_version = swift_version,
        )
    return struct(reasons = reasons, pkgs = pkgs, pkg_info = pkg_info)

def _major_minor(version):
    """Returns the `major.minor` prefix of a dotted version string."""
    return ".".join(version.split(".")[:2])

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

    # The live `Package.resolved` is absent for a package with no remote deps.
    resolved_text = manifest_files.read_text(module_ctx, slice.resolved)
    resolved_map = {}
    if resolved_text != None:
        resolved_map = json.decode(resolved_text, default = None)

    # The manifest lists are generated into the committed `inc.MODULE.bazel`.
    # An inconsistent list means the cache needs regenerating, so the slice
    # is stale rather than an error.
    invalid = slices.validate(slice)
    if invalid != None:
        return _ok(_new_evaluated(
            slice,
            [invalid],
            _stale_pkgs(slice, resolved_map),
        ))

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
          desc_label, local_path, dep, swift_version)`, where `kind` is
          `source_control` or `local`, `dep` is the `pkginfos.new_dependency`
          struct, and `swift_version` is the `major.minor` of the slice's
          `_main/swift_version.txt`. A stale entry is
          `struct(kind, pin_key, swift_version = None)`, where `kind` is `source_control`,
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

_SWIFT_PACKAGE_REPO_NAME = "swift_package"

_DEFAULT_RULES = struct(
    git = swift_package,
    local = local_swift_package,
    aliases = swift_package_aliases,
    stale = stale_swift_package,
    tool_repo = swift_package_tool_repo,
    package_repos = swift_deps_package_repos,
)

def _root_module_aliases(evaluated):
    """The SE-0339 aliases by identity from the fresh root slices.

    If the root slices disagree, the first one wins and a warning is printed.
    """
    result = None
    first_dir = None
    for e in evaluated:
        if not e.slice.is_root or e.stale:
            continue
        if result == None:
            result = e.module_aliases_by_id
            first_dir = e.slice.dir
        elif result != e.module_aliases_by_id:
            # buildifier: disable=print
            print((
                "WARNING: the root slices declare different module aliases; " +
                "using the aliases of slice `{}`."
            ).format(first_dir))
            break
    return result if result != None else {}

def _group_slice(evaluated, identity, group):
    """The slice whose entry a merge group was built from."""
    for e in evaluated:
        if e.stale:
            continue
        entry = e.pkgs.get(identity)
        if entry != None and entry.dump_label == group.entry.dump_label:
            return e.slice
    fail("No slice holds the group entry of `{}`.".format(identity))

def _patch_tags_for_tool(module_ctx, root, config_pkgs):
    """The `configure_package` tag with patches for each root identity.

    The tag is the one the package repository applies: `config_pkg_for` on
    the dependency of the first fresh root slice that has it. An identity that
    only stale root slices know falls back to the first tag that
    `_patch_tags_by_identity` matches, including on the slice's pins. That
    way the first cache run after `init`, whose slice lists no manifests,
    still copies the patches.

    Returns:
        A `dict` of identity to tag, for tags with patches.
    """
    result = {}
    seen = {}
    for e in root:
        if e.stale:
            continue
        for identity in sorted(e.pkgs.keys()):
            if identity in seen:
                continue
            seen[identity] = None
            tag = swift_deps_common.config_pkg_for(config_pkgs, e.pkgs[identity].dep)
            if tag and tag.patches:
                result[identity] = tag
    for e in root:
        tags_by_identity = _patch_tags_by_identity(
            module_ctx,
            e.slice,
            config_pkgs,
            pinned = e.pkgs.keys(),
        )
        for identity in sorted(tags_by_identity.keys()):
            if identity in seen:
                continue
            seen[identity] = None
            result[identity] = tags_by_identity[identity][0]
    return result

def _swift_package_kwargs(module_ctx, root, config_pkgs, config_swift_package):
    """The `swift_package_tool_repo` kwargs for the evaluated root slices."""
    root_slices = [e.slice for e in root]
    swift = root_slices[0].swift
    for s in root_slices[1:]:
        if s.swift != swift:
            fail((
                "the root slices name different `swift` labels: `{a}` " +
                "(slice `{a_dir}`) and `{b}` (slice `{b_dir}`); all root " +
                "slices must resolve the same `Package.swift`"
            ).format(a = str(swift), a_dir = root_slices[0].dir, b = str(s.swift), b_dir = s.dir))

        # The tool runs once for every root slice with one set of flags, so
        # the slices must agree on the `from_package` labels in them.
        for attr in ("netrc", "registries"):
            a = getattr(root_slices[0], attr)
            b = getattr(s, attr)
            if a != b:
                fail((
                    "the root slices name different `{attr}` labels: " +
                    "`{a}` (slice `{a_dir}`) and `{b}` (slice `{b_dir}`); " +
                    "all root slices must use the same `{attr}`"
                ).format(
                    attr = attr,
                    a = str(a),
                    a_dir = root_slices[0].dir,
                    b = str(b),
                    b_dir = s.dir,
                ))
    package = paths.join(swift.package, swift.name)

    tag_by_identity = _patch_tags_for_tool(module_ctx, root, config_pkgs)
    patch_specs = {}
    patch_files = []
    for identity in sorted(tag_by_identity.keys()):
        tag = tag_by_identity[identity]
        files = []
        for f in tag.patches:
            if f not in files:
                files.append(f)
        patch_specs[identity] = {
            "args": tag.patch_args,
            "files": [str(f) for f in files],
        }
        patch_files.extend([f for f in files if f not in patch_files])

    return dict(
        name = _SWIFT_PACKAGE_REPO_NAME,
        package = package,
        package_path = package,
        swift_label = str(swift),
        slices = json.encode([
            {
                "config": s.config,
                "config_value": s.config,
                "dir": s.dir,
                "package_value": "//" + s.dir,
            }
            for s in root_slices
        ]),
        flags = staleness.render_flags(
            config_swift_package,
            netrc = root_slices[0].netrc,
            registries = root_slices[0].registries,
        ),
        patch_specs = json.encode(patch_specs),
        patch_files = patch_files,
    )

def _declare(
        module_ctx,
        evaluated,
        config_pkgs,
        config_swift_package,
        target_mods_by_repo,
        matched_target_mod_repos,
        available_target_mod_repos,
        inference_config,
        package_rules = _DEFAULT_RULES):
    """Declares the repositories of the evaluated slices.

    Per identity: one repository when every slice holds the same package;
    otherwise one hidden repository per group plus an alias repository; and a
    stale repository when only stale slices know the identity. The root
    slices also get one `@swift_package`.

    Args:
        module_ctx: A `module_ctx`.
        evaluated: A `list` of `slice_declarations.evaluate` results for
            the root module's slices.
        config_pkgs: A `dict` of name to `configure_package` tag.
        config_swift_package: A `configure_swift_package` tag or `None`.
        target_mods_by_repo: A `dict` of repository name to target
            modifications.
        matched_target_mod_repos: A mutable `dict` recording the repository
            names from `target_mods_by_repo` that were found.
        available_target_mod_repos: A mutable `dict` recording every
            user-visible repository name.
        inference_config: Root-owned dependency inference configuration.
        package_rules: The repository rules. Tests pass fakes.

    Returns:
        A `struct(direct, direct_dev)` of repository names for the root
        module.
    """
    merged = slice_merge.merge([_to_merge_entry(e) for e in evaluated])
    first_by_config = {}
    for e in evaluated:
        first_by_config.setdefault(e.slice.config, e)

    module_aliases_by_id = _root_module_aliases(evaluated)
    dep_module_aliases = json.encode(module_aliases_by_id) if module_aliases_by_id else ""

    # Record the user-visible names before declaring anything, as v1 does.
    for identity, m in merged.items():
        repo_name = bazel_repo_names.from_identity(identity)
        available_target_mod_repos[repo_name] = True
        if repo_name in target_mods_by_repo:
            matched_target_mod_repos[repo_name] = True
        deps = [g.entry.dep for g in m.groups]
        if not deps:
            deps = [struct(name = identity, identity = identity)]
        swift_deps_common.record_inference_packages(inference_config, deps)

    package_repos = swift_deps_common.declare_package_repos(
        [bazel_repo_names.from_identity(identity) for identity in merged],
        package_repos_rule = package_rules.package_repos,
    )

    def _declare_pkg(name, identity, group):
        slice = _group_slice(evaluated, identity, group)
        entry = group.entry
        dep = entry.dep
        repo_name = bazel_repo_names.from_identity(identity)
        config_pkg = swift_deps_common.config_pkg_for(config_pkgs, dep)
        repo = swift_deps_common.pkg_repo_kwargs(
            name = name,
            dep = dep,
            config_pkg = config_pkg,
            make_files_read_only = slice.make_files_read_only,
            local_path = entry.local_path,
            target_deps = config_pkg.target_deps if config_pkg else {},
            module_aliases = module_aliases_by_id.get(identity, {}),
            dep_module_aliases = dep_module_aliases,
            target_mods = bazel_target_mods.encode(
                target_mods_by_repo.get(repo_name, []),
            ),
            package_repos = package_repos,
            inference_settings = swift_deps_common.inference_settings(
                inference_config,
                dep.name,
                repo_name,
            ),
        )
        v2_kwargs = {}
        if repo.kind == "git":
            # Binary artifacts download with the slice tag's `.netrc`.
            v2_kwargs["netrc"] = slice.netrc
        getattr(package_rules, repo.kind)(
            dump_manifest = entry.dump_label,
            desc_manifest = entry.desc_label,
            swift_version = slices.cache_label(slice, _MAIN, "swift_version.txt"),
            slice_dir = slice.dir,
            **dicts.add(repo.kwargs, v2_kwargs)
        )

    for identity, m in merged.items():
        repo_name = bazel_repo_names.from_identity(identity)
        if m.identical:
            _declare_pkg(repo_name, identity, m.groups[0])
            continue
        if not m.groups:
            stale_slice = [
                e.slice
                for e in evaluated
                if e.stale and identity in e.pkgs
            ][0]
            package_rules.stale(
                name = repo_name,
                message = slice_messages.stale(stale_slice.dir, stale_slice.config),
            )
            continue
        branches = {}
        for group in m.groups:
            group_repo = slice_merge.repo_name(identity, group.index)
            _declare_pkg(group_repo, identity, group)
            for config in group.configs:
                branches.setdefault(config, group_repo)
        stale_messages = {}
        for config in m.stale_configs:
            if config in branches:
                continue
            branches[config] = ""
            e = first_by_config[config]
            if e.stale:
                stale_messages[config] = slice_messages.stale(e.slice.dir, config)
            else:
                stale_messages[config] = slice_messages.missing(e.slice.dir, config, identity)
        package_rules.aliases(
            name = repo_name,
            branches = branches,
            stale_messages = stale_messages,
        )

    root = [e for e in evaluated if e.slice.is_root]
    if not root:
        return struct(direct = [], direct_dev = [])

    package_rules.tool_repo(**_swift_package_kwargs(
        module_ctx,
        root,
        config_pkgs,
        config_swift_package,
    ))

    # As v1: the root package's direct deps, plus every package whose
    # `configure_package` sets `publicly_expose_all_targets`. A stale slice
    # has no package info, so all of its names count as direct.
    direct = {}
    direct_dev = {}
    for e in root:
        if e.stale:
            identities = list(e.pkgs.keys())
        else:
            identities = [dep.identity for dep in e.pkg_info.dependencies]
            for identity, entry in e.pkgs.items():
                config_pkg = swift_deps_common.config_pkg_for(config_pkgs, entry.dep)
                if config_pkg and config_pkg.publicly_expose_all_targets:
                    identities.append(identity)
        names = direct_dev if e.slice.is_dev else direct
        for identity in identities:
            names[bazel_repo_names.from_identity(identity)] = None
    return struct(
        direct = sorted(direct.keys()) + [_SWIFT_PACKAGE_REPO_NAME],
        direct_dev = sorted([n for n in direct_dev if n not in direct]),
    )

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
