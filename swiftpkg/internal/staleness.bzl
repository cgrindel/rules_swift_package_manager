"""Detects whether a slice's `swift_deps_cache` is stale.

A slice is fresh when every cached input matches its live counterpart and
every listed manifest exists and decodes as JSON. The comparison is exact text. Nothing here
calls `fail()` on a missing file; a missing file makes the slice stale.

The pairing logic takes a `reader` struct so that unit tests can pass an
in-memory fake. `collect` builds the real reader from a `module_ctx`.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(":slices.bzl", "slices")

_MAIN = "_main"
_CACHED_SUFFIX = ".cached"
_VARIANT_PREFIX = "Package@swift-"
_VARIANT_SUFFIX = ".swift"

# The `configure_swift_package` attribute defaults in
# `swift_package_tool_attrs.bzl`. An `attr` object does not expose its
# default, so they are repeated here and checked by a unit test.
_DEFAULTS = {
    "cache_path": ".cache",
    "config_path": ".config",
    "dependency_caching": True,
    "manifest_cache": "shared",
    "manifest_caching": True,
    "replace_scm_with_registry": False,
    "security_path": ".security",
    "use_registry_identity_for_scm": False,
}

# Always rendered, so the tool and this module agree on every value.
_ALWAYS_KEYS = [
    "dependency_caching",
    "manifest_cache",
    "manifest_caching",
    "replace_scm_with_registry",
    "use_registry_identity_for_scm",
]

# Rendered only when they differ from the default, so the tool's defaults
# under `<slice>/.build` apply otherwise.
_NON_DEFAULT_KEYS = ["cache_path", "config_path", "security_path"]

# Workspace-relative paths of a `Label`, rendered when set.
_LABEL_KEYS = ["netrc", "registries"]

def _workspace_relative(label):
    if not label.package:
        return label.name
    return "{}/{}".format(label.package, label.name)

def _render_value(value):
    if type(value) == "bool":
        return "true" if value else "false"
    return str(value)

def _render_flags(config_swift_package):
    """Renders the `configure_swift_package` flags as the tool writes them.

    The output must equal `SwiftPMFlags.normalized()` in
    `tools/swift_deps_tool/Sources/SwiftPMFlags.swift` for the flags that the
    extension passes to the tool: one `key=value\\n` line per flag, sorted by
    key. `build_path` is never included.

    Args:
        config_swift_package: A `configure_swift_package` tag, a `struct`
            with the same attributes, or `None` for the defaults.

    Returns:
        A `string`.
    """
    values = {}
    for key in _ALWAYS_KEYS:
        value = _DEFAULTS[key]
        if config_swift_package != None:
            value = getattr(config_swift_package, key)
        values[key] = _render_value(value)
    if config_swift_package != None:
        for key in _NON_DEFAULT_KEYS:
            value = getattr(config_swift_package, key)
            if value != _DEFAULTS[key]:
                values[key] = value
        # A `configure_swift_package` tag has no `netrc` or `registries`
        # attribute; they live on `from_package`.
        for key in _LABEL_KEYS:
            label = getattr(config_swift_package, key, None)
            if label != None:
                values[key] = _workspace_relative(label)
    return "".join([
        "{}={}\n".format(key, values[key])
        for key in sorted(values.keys())
    ])

def _new_input(name, live, cached, error = None):
    return struct(name = name, live = live, cached = cached, error = error)

def _evaluate(inputs):
    """Compares each live input with its cached copy.

    Args:
        inputs: A `list` of `struct(name, live, cached)`, where `live` and
            `cached` are `string` contents or `None` when missing. An input
            may also carry `error`, a `string` that makes it stale on its own
            (for example, a manifest that is not valid JSON).

    Returns:
        A `struct` with `stale` (`bool`) and `reasons` (one `string` per
        stale input, in input order).
    """
    reasons = []
    for i in inputs:
        error = getattr(i, "error", None)
        if error != None:
            reasons.append("{}: {}".format(i.name, error))
        elif i.live == None:
            reasons.append("{}: missing live file".format(i.name))
        elif i.cached == None:
            reasons.append("{}: missing cached copy".format(i.name))
        elif i.live != i.cached:
            reasons.append("{}: differs from cached copy".format(i.name))
    return struct(stale = len(reasons) > 0, reasons = reasons)

# MARK: - Pairing

def _exists(reader, path_or_label):
    # `path.exists` registers no watch. Watch first so that creating a
    # missing file later re-evaluates the extension.
    reader.watch(path_or_label)
    return reader.exists(path_or_label)

def _read(reader, path_or_label):
    if not _exists(reader, path_or_label):
        return None
    return reader.read(path_or_label)

def _is_variant(name):
    return (
        name.startswith(_VARIANT_PREFIX) and
        name.endswith(_VARIANT_SUFFIX) and
        len(name) > len(_VARIANT_PREFIX) + len(_VARIANT_SUFFIX)
    )

def _list_dir(reader, dir):
    if not _exists(reader, dir):
        return []
    return reader.readdir(dir)

def _manifest_inputs(reader, slice, identity, live_swift, live_dir):
    """Inputs for a `Package.swift` and its variants.

    Args:
        reader: The reader `struct`.
        slice: The slice `struct`.
        identity: The cache identity.
        live_swift: A `Label` or path of the live `Package.swift`.
        live_dir: The path of the directory that holds `live_swift`.

    Returns:
        A `list` of inputs.
    """
    inputs = []
    inputs.append(_new_input(
        name = "{}/Package.swift{}".format(identity, _CACHED_SUFFIX),
        live = _read(reader, live_swift),
        cached = _read(
            reader,
            slices.cache_label(slice, identity, "Package.swift" + _CACHED_SUFFIX),
        ),
    ))

    live_variants = sorted([
        n
        for n in _list_dir(reader, live_dir)
        if _is_variant(n)
    ])
    for n in live_variants:
        path = reader.join(live_dir, n)
        inputs.append(_new_input(
            name = "{}/{}{}".format(identity, n, _CACHED_SUFFIX),
            live = _read(reader, path),
            cached = _read(
                reader,
                slices.cache_label(slice, identity, n + _CACHED_SUFFIX),
            ),
        ))

    cache_dir = reader.dirname(
        slices.cache_label(slice, identity, "Package.swift" + _CACHED_SUFFIX),
    )
    cached_only = sorted([
        n[:-len(_CACHED_SUFFIX)]
        for n in _list_dir(reader, cache_dir)
        if n.endswith(_CACHED_SUFFIX) and
           _is_variant(n[:-len(_CACHED_SUFFIX)]) and
           n[:-len(_CACHED_SUFFIX)] not in live_variants
    ])
    for n in cached_only:
        inputs.append(_new_input(
            name = "{}/{}{}".format(identity, n, _CACHED_SUFFIX),
            live = None,
            cached = _read(
                reader,
                slices.cache_label(slice, identity, n + _CACHED_SUFFIX),
            ),
        ))
    return inputs

def _file_system_paths(reader, slice, identity):
    """The `fileSystem` dependency paths in a cached `desc.json`."""
    text = _read(reader, slices.cache_label(slice, identity, "desc.json"))
    if text == None:
        return []
    desc = json.decode(text, default = None)
    if type(desc) != "dict":
        return []
    paths = []
    for dep in desc.get("dependencies", []):
        if type(dep) != "dict" or dep.get("type") != "fileSystem":
            continue
        path = dep.get("path")
        if type(path) == "string" and path:
            paths.append(path)
    return paths

def _local_packages(reader, slice, root_dir):
    """Discovers local packages to a fixed point from cached `desc.json`.

    Returns:
        A `list` of `struct(identity, dir)` in discovery order.
    """
    visited = {root_dir: True}
    work = [struct(identity = _MAIN, dir = root_dir)]
    found = []

    # Starlark has no `while`; each package is pushed at most once.
    for _ in range(1000000):
        if not work:
            break
        pkg = work.pop(0)
        for rel in _file_system_paths(reader, slice, pkg.identity):
            dir = reader.join(pkg.dir, rel)
            if dir in visited:
                continue
            visited[dir] = True
            local = struct(
                identity = dir.split("/")[-1].lower(),
                dir = dir,
            )
            found.append(local)
            work.append(local)
    return found

def _collect_with_reader(reader, slice, config_swift_package, patch_files_by_identity):
    """Builds the staleness inputs for a slice.

    See `collect` for the order.

    Args:
        reader: A `struct` with `exists(path_or_label)`, `read(path_or_label)`,
            `readdir(path)` (basenames), `watch(path)`,
            `dirname(path_or_label)`, and `join(dir, rel)` (normalized;
            `rel` may be absolute).
        slice: A slice `struct` from `slices.new`.
        config_swift_package: A `configure_swift_package` tag or `None`.
        patch_files_by_identity: A `dict` of identity to `list` of patch
            `Label`.

    Returns:
        A `list` of `struct(name, live, cached)`.
    """
    root_dir = reader.dirname(slice.swift)

    # (1), (2) Root Package.swift and variants.
    inputs = _manifest_inputs(
        reader,
        slice,
        _MAIN,
        slice.swift,
        root_dir,
    )

    # (3) Package.resolved, unless absent on both sides.
    resolved_live = _read(reader, slice.resolved)
    resolved_cached = _read(
        reader,
        slices.cache_label(slice, _MAIN, "Package.resolved" + _CACHED_SUFFIX),
    )
    if resolved_live != None or resolved_cached != None:
        inputs.append(_new_input(
            name = "{}/Package.resolved{}".format(_MAIN, _CACHED_SUFFIX),
            live = resolved_live,
            cached = resolved_cached,
        ))

    # (4) Flags.
    inputs.append(_new_input(
        name = "{}/flags{}".format(_MAIN, _CACHED_SUFFIX),
        live = _render_flags(config_swift_package),
        cached = _read(
            reader,
            slices.cache_label(slice, _MAIN, "flags" + _CACHED_SUFFIX),
        ),
    ))

    # (5) The Swift version the tool ran with. Only its existence matters
    # here; `swift_version_check` compares the contents at build time.
    swift_version_exists = _exists(
        reader,
        slices.cache_label(slice, _MAIN, "swift_version.txt"),
    )
    inputs.append(_new_input(
        name = "{}/swift_version.txt".format(_MAIN),
        live = "",
        cached = "" if swift_version_exists else None,
    ))

    # (6) registries.json, when configured or when a copy is left over.
    registries = None
    if config_swift_package != None:
        registries = config_swift_package.registries
    registries_cached = _read(
        reader,
        slices.cache_label(slice, _MAIN, "registries.json" + _CACHED_SUFFIX),
    )
    if registries != None or registries_cached != None:
        inputs.append(_new_input(
            name = "{}/registries.json{}".format(_MAIN, _CACHED_SUFFIX),
            live = _read(reader, registries) if registries != None else None,
            cached = registries_cached,
        ))

    # (7) Patch files.
    for identity in sorted(patch_files_by_identity.keys()):
        for patch in patch_files_by_identity[identity]:
            basename = "patches/" + patch.name.split("/")[-1]
            inputs.append(_new_input(
                name = "{}/{}".format(identity, basename),
                live = _read(reader, patch),
                cached = _read(
                    reader,
                    slices.cache_label(slice, identity, basename),
                ),
            ))

    # (8) Local packages, reached by path.
    for local in _local_packages(reader, slice, root_dir):
        inputs.extend(_manifest_inputs(
            reader,
            slice,
            local.identity,
            reader.join(local.dir, "Package.swift"),
            local.dir,
        ))

    # (9) Every listed manifest must exist and decode as JSON. A
    # merge-conflicted manifest marks the slice stale rather than failing the
    # extension when it decodes the manifest later.
    for identity in slice.identities:
        for basename in ["dump.json", "desc.json"]:
            text = _read(reader, slices.cache_label(slice, identity, basename))
            error = None
            if text != None and json.decode(text, default = None) == None:
                error = "not valid JSON"
            inputs.append(_new_input(
                name = "{}/{}".format(identity, basename),
                live = "",
                cached = "" if text != None else None,
                error = error,
            ))
    return inputs

def _new_module_ctx_reader(module_ctx):
    def _exists(path_or_label):
        return module_ctx.path(path_or_label).exists

    def _read(path_or_label):
        return module_ctx.read(module_ctx.path(path_or_label))

    def _readdir(path):
        return [p.basename for p in module_ctx.path(path).readdir()]

    def _watch(path):
        module_ctx.watch(module_ctx.path(path))

    def _dirname(path_or_label):
        return str(module_ctx.path(path_or_label).dirname)

    def _join(dir, rel):
        # Normalize first so that `..` never reaches Bazel. `paths.join`
        # returns `rel` when it is absolute.
        return str(module_ctx.path(paths.normalize(paths.join(str(dir), rel))))

    return struct(
        exists = _exists,
        read = _read,
        readdir = _readdir,
        watch = _watch,
        dirname = _dirname,
        join = _join,
    )

def _collect(module_ctx, slice, config_swift_package, patch_files_by_identity):
    """Builds the staleness inputs for a slice.

    Inputs, in order:
    1. `Package.swift` and `_main/Package.swift.cached`.
    2. Each live `Package@swift-*.swift` beside it, then each cached variant
       with no live counterpart.
    3. `Package.resolved`, unless absent on both sides.
    4. The rendered flags and `_main/flags.cached`.
    5. The existence of `_main/swift_version.txt`.
    6. `registries.json`, when configured or when a cached copy exists.
    7. Each patch file, by sorted identity.
    8. Each local package's `Package.swift` and variants, in discovery
       order.
    9. Each identity's `dump.json` and `desc.json`: each must exist and
       decode as JSON.

    Every path checked for existence, and every directory listed, is passed
    to `module_ctx.watch` first, so creating or changing any input
    re-evaluates the extension.

    Names are paths relative to the slice's `swift_deps_cache` directory.

    Args:
        module_ctx: A `module_ctx`.
        slice: A slice `struct` from `slices.new`.
        config_swift_package: A `configure_swift_package` tag or `None`.
        patch_files_by_identity: A `dict` of identity to `list` of patch
            `Label`.

    Returns:
        A `list` of `struct(name, live, cached)` for `staleness.evaluate`.
    """
    return _collect_with_reader(
        _new_module_ctx_reader(module_ctx),
        slice,
        config_swift_package,
        patch_files_by_identity,
    )

staleness = struct(
    collect = _collect,
    evaluate = _evaluate,
    render_flags = _render_flags,
)

staleness_testing = struct(
    collect_with_reader = _collect_with_reader,
    defaults = _DEFAULTS,
)
