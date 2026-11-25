"""Attaches the slice's Swift version check to generated declarations."""

load(":bazel_target_mods.bzl", "bazel_target_mods")
load(":build_decls.bzl", "build_decls")

# The kinds whose targets carry the check in `data`, so that building any of
# them runs the check's validation action. `apple_dynamic_xcframework_import`
# has no `data` attribute, so it is not listed.
_KINDS = [
    "apple_static_xcframework_import",
    "cc_library",
    "objc_library",
    "swift_binary",
    "swift_compiler_plugin",
    "swift_library",
    "swift_test",
]

_NAME = "swift_version_check"

def _has_label(value, label):
    """Reports whether `value` already ends with `[label]`.

    Args:
        value: An attribute value: a `list` or a Starlark codegen expression.
        label: The label `string`.

    Returns:
        A `bool`.
    """
    if type(value) == "list":
        return label in value

    # An expression built by `bazel_target_mods` (`<existing> + [label]`).
    members = getattr(value, "members", None)
    if members:
        last = members[-1]
        return type(last) == "list" and label in last
    return False

def _attach(decls, label = ":" + _NAME):
    """Adds `label` to the `data` of every library, binary and test decl.

    Args:
        decls: A `list` of declaration `struct` values as returned by
            `build_decls.new`.
        label: The label of the `swift_version_check` target as a `string`.

    Returns:
        A new `list` of declarations. The input is not mutated.
    """
    results = []
    for decl in decls:
        existing = decl.attrs.get("data") if decl.kind in _KINDS else None
        if decl.kind not in _KINDS or (
            existing != None and _has_label(existing, label)
        ):
            results.append(decl)
            continue
        attrs = dict(decl.attrs)
        bazel_target_mods.append(attrs, "data", [label])
        results.append(build_decls.new(
            kind = decl.kind,
            name = decl.name,
            attrs = attrs,
            comments = decl.comments,
        ))
    return results

def _decl(slice_dir):
    """Returns the `swift_version_check` declaration for a slice.

    Args:
        slice_dir: The workspace-relative slice directory as a `string`.

    Returns:
        A declaration `struct` as returned by `build_decls.new`.
    """
    return build_decls.new(
        _NAME,
        _NAME,
        attrs = {
            "slice_dir": slice_dir,
            "version_file": "swift_version.txt",
        },
    )

swift_version_checks = struct(
    attach = _attach,
    decl = _decl,
    name = _NAME,
)
