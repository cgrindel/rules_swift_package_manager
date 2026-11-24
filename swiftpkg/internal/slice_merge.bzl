"""Module for merging evaluated slices per package identity.

For each package identity found in any slice, the merge decides whether one
ordinary repository suffices (the identity is identical across all slices) or
whether hidden per-group repositories plus an alias repository are needed.
"""

load(":bazel_repo_names.bzl", "bazel_repo_names")

def _merge_or_error(slice_entries):
    """Merges slice entries per identity, returning an error instead of failing.

    Args:
        slice_entries: A `list` of `struct(config, dir, stale, pkgs)` values,
            where `pkgs` is a `dict` of identity to
            `struct(kind, pin_key, dump_text, desc_text, dump_label,
            desc_label, local_path, swift_version)`, where `swift_version` is
            the trimmed text of the slice's `_main/swift_version.txt`. A stale
            slice's pkg structs carry only `kind` and `pin_key` (and
            `swift_version = None`).

    Returns:
        A `struct(error, result)`. On success, `error` is `None` and `result`
        is the `dict` described in `slice_merge.merge`. When two fresh slices
        disagree on an identity's kind, `error` is a message and `result` is
        `None`. Stale slices never cause a kind conflict.
    """
    any_stale = False
    identities = {}
    for se in slice_entries:
        if se.stale:
            any_stale = True
        identities.update({identity: None for identity in se.pkgs})

    result = {}
    for identity in sorted(identities):
        # The kind comes from the fresh slices. A stale slice's pin may still
        # name an older kind (e.g. a remote pin for a package that a fresh
        # slice now has as local), so a stale entry's kind is used only when
        # no fresh slice has the identity.
        kind = None
        stale_kind = None
        for se in slice_entries:
            entry = se.pkgs.get(identity)
            if entry == None:
                continue
            if se.stale:
                if stale_kind == None:
                    stale_kind = entry.kind
            elif kind == None:
                kind = entry.kind
            elif kind != entry.kind:
                return struct(
                    error = """\
Package `{identity}` has conflicting kinds across slices: `{a}` and `{b}`.\
""".format(identity = identity, a = kind, b = entry.kind),
                    result = None,
                )
        if kind == None:
            kind = stale_kind

        groups = []
        groups_by_key = {}
        stale_configs = []
        present_count = 0
        for se in slice_entries:
            entry = se.pkgs.get(identity)
            if entry != None:
                present_count += 1
            if se.stale or entry == None:
                stale_configs.append(se.config)
                continue
            key = (
                entry.pin_key,
                entry.dump_text,
                entry.desc_text,
                entry.swift_version,
            )
            group = groups_by_key.get(key)
            if group == None:
                group = struct(
                    index = len(groups) + 1,
                    configs = [],
                    entry = entry,
                )
                groups_by_key[key] = group
                groups.append(group)
            group.configs.append(se.config)

        identical = (
            not any_stale and
            present_count == len(slice_entries) and
            len(groups) == 1
        )
        result[identity] = struct(
            kind = kind,
            identical = identical,
            any_stale = any_stale,
            groups = groups,
            stale_configs = stale_configs,
        )

    return struct(error = None, result = result)

def _merge(slice_entries):
    """Merges slice entries per package identity.

    Args:
        slice_entries: A `list` of `struct(config, dir, stale, pkgs)` values.
            See `slice_merge_testing.merge_or_error` for details.

    Returns:
        A `dict` of identity (sorted) to
        `struct(kind, identical, any_stale, groups, stale_configs)`.
        `groups` is a `list` of `struct(index, configs, entry)` built from the
        fresh slices that contain the identity, keyed by
        `(pin_key, dump_text, desc_text, swift_version)` and numbered from 1 in input order.
        `stale_configs` lists the configs whose slice is stale or lacks the
        identity, in input order. `identical` is true only when no slice is
        stale and every slice holds the same entry, in which case there is
        exactly one group.
    """
    merged = _merge_or_error(slice_entries)
    if merged.error != None:
        fail(merged.error)
    return merged.result

def _repo_name(identity, group_index):
    """Returns the hidden repository name for an identity's group.

    Args:
        identity: The Swift package identity as a `string`.
        group_index: The 1-based group index as an `int`.

    Returns:
        The repository name as a `string`.
    """
    return bazel_repo_names.from_identity(identity) + "__slice_" + str(group_index)

slice_merge = struct(
    merge = _merge,
    repo_name = _repo_name,
)

slice_merge_testing = struct(
    merge_or_error = _merge_or_error,
)
