"""Data model for a slice: one resolution of `Package.swift` for one config."""

_MAIN_IDENTITY = "_main"

def _new(
        config,
        swift,
        resolved,
        dump_manifests,
        desc_manifests,
        is_root,
        is_dev,
        netrc = None,
        registries = None,
        make_files_read_only = False):
    """Create a slice.

    Args:
        config: A `Label` or `string` identifying the build configuration.
        swift: The `Label` of the `Package.swift`.
        resolved: The `Label` of the slice's `Package.resolved`. Its package is
            the slice directory.
        dump_manifests: A `dict` of identity to `Label` of the cached
            `swift package dump-package` JSON.
        desc_manifests: A `dict` of identity to `Label` of the cached
            `swift package describe` JSON.
        is_root: Whether the declaring module is the root module.
        is_dev: Whether the declaring tag is a dev dependency.
        netrc: Optional. The `Label` of the tag's `.netrc` file, passed to
            the package repositories for binary-artifact downloads and
            rendered into the tool flags.
        registries: Optional. The `Label` of the tag's `registries.json`
            file, rendered into the tool flags and watched for staleness.
        make_files_read_only: Whether the package repositories make their
            files read-only.

    Returns:
        A `struct` representing the slice.
    """
    return struct(
        config = str(config) if type(config) == "Label" else config,
        swift = swift,
        resolved = resolved,
        dir = resolved.package,
        package_label = "@@{repo}//{pkg}".format(
            repo = resolved.repo_name,
            pkg = resolved.package,
        ),
        dump_manifests = dump_manifests,
        desc_manifests = desc_manifests,
        identities = sorted(dump_manifests.keys()),
        is_root = is_root,
        is_dev = is_dev,
        netrc = netrc,
        registries = registries,
        make_files_read_only = make_files_read_only,
    )

def _validate(slice):
    """Check a slice for consistency.

    Args:
        slice: A `struct` as returned by `slices.new`.

    Returns:
        `None` if the slice is valid; otherwise, an error `string`.
    """
    dump_ids = set(slice.dump_manifests.keys())
    desc_ids = set(slice.desc_manifests.keys())
    if dump_ids != desc_ids:
        differing = sorted(dump_ids.symmetric_difference(desc_ids))
        return (
            "slice `{dir}`: dump_manifests and desc_manifests have " +
            "different identities; differing: {ids}"
        ).format(dir = slice.dir, ids = ", ".join(differing))

    # Empty dicts are what `init` writes before the first cache run; the
    # slice is then stale, not invalid.
    if dump_ids and _MAIN_IDENTITY not in dump_ids:
        return "slice `{dir}`: dump_manifests is missing the `{main}` identity".format(
            dir = slice.dir,
            main = _MAIN_IDENTITY,
        )

    for attr in ("dump_manifests", "desc_manifests"):
        manifests = getattr(slice, attr)
        for identity in sorted(manifests.keys()):
            lbl = manifests[identity]
            if (lbl.repo_name != slice.resolved.repo_name or
                lbl.package != slice.resolved.package):
                return (
                    "slice `{dir}`: {attr} entry for `{identity}` is " +
                    "outside the slice package: {lbl}"
                ).format(
                    dir = slice.dir,
                    attr = attr,
                    identity = identity,
                    lbl = str(lbl),
                )
    return None

def _cache_label(slice, identity, basename):
    """Return the label of a cached file for an identity in a slice.

    Args:
        slice: A `struct` as returned by `slices.new`.
        identity: The package identity.
        basename: The file name inside the identity's cache directory.

    Returns:
        A `Label`.
    """
    return Label("{pkg}:swift_deps_cache/{identity}/{basename}".format(
        pkg = slice.package_label,
        identity = identity,
        basename = basename,
    ))

def _is_v2_tag(tag):
    """Whether a `from_package` tag describes a v2 slice.

    `config` marks a v2 tag even when the manifest dicts are still empty, as
    `init` writes them before the first cache run.

    Args:
        tag: A `from_package` tag.

    Returns:
        A `bool`.
    """
    return tag.config != None or len(tag.dump_manifests) > 0

slices = struct(
    is_v2_tag = _is_v2_tag,
    new = _new,
    validate = _validate,
    cache_label = _cache_label,
)
