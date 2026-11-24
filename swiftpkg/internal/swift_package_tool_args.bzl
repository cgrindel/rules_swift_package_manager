"""Renders the `args` of the generated `swift_package_tool_rule` targets."""

load(":slice_messages.bzl", "slice_messages")
load(":starlark_codegen.bzl", scg = "starlark_codegen")

_TARGET_OS_SELECT = {
    "@@platforms//os:ios": ["ios"],
    "@@platforms//os:linux": ["linux"],
    "@@platforms//os:macos": ["macos"],
    "@@platforms//os:tvos": ["tvos"],
    "@@platforms//os:visionos": ["visionos"],
    "@@platforms//os:watchos": ["watchos"],
    "//conditions:default": ["unknown"],
}

# The patch args that `swift_package` applies when a package lists none.
_DEFAULT_PATCH_ARGS = ["-p0"]

def _slice_select(slices, attr_name, no_match_error):
    return scg.new_fn_call(
        "select",
        {s.config: [getattr(s, attr_name)] for s in slices},
        no_match_error = no_match_error,
    )

def _flag_lines(flags):
    if type(flags) == "string":
        flags = flags.split("\n")
    return [f for f in flags if f]

def _render(cmd, package_path, swift_label, slices, flags, patch_specs):
    """Renders the `args` of a `swift_package_tool_rule` target.

    Args:
        cmd: The tool command (`resolve`, `update` or `cache`) as a `string`.
        package_path: The workspace-relative path to `Package.swift`.
        swift_label: The `swift_label` as written in the tag.
        slices: A `list` of `struct` values with `config` (the canonical
            config label, used as a `select()` key), `config_label` (the
            config label as written in the tag), `dir` (the
            workspace-relative slice directory) and `package_label` (the
            slice package label as written).
        flags: The flags as rendered by `staleness.render_flags`: a
            `key=value\\n` `string` or a `list` of `key=value` strings, in
            sorted order.
        patch_specs: A `dict` mapping a package identity to a `struct` with
            `files` (a `list` of patch labels) and `args` (a `list` of
            patch args).

    Returns:
        A `list` of segments: `list` values of strings and `select()`
        function calls. Pass it to `swift_package_tool_args.to_expr` to
        concatenate the segments.
    """
    slices = sorted(slices, key = lambda s: s.config)
    no_match_error = slice_messages.no_match([s.config for s in slices])

    tail = []
    for flag in _flag_lines(flags):
        tail.extend(["--flag", flag])
    identities = sorted(patch_specs.keys())
    for identity in identities:
        for patch in patch_specs[identity].files:
            tail.extend([
                "--patch",
                "{}=$(rootpath {})".format(identity, patch),
            ])
    for identity in identities:
        spec = patch_specs[identity]
        if not spec.files:
            continue
        for arg in spec.args or _DEFAULT_PATCH_ARGS:
            tail.extend(["--patch-args", "{}={}".format(identity, arg)])

    segments = [
        [
            cmd,
            "--package",
            package_path,
            "--swift-label",
            swift_label,
            "--slice",
        ],
        _slice_select(slices, "dir", no_match_error),
        ["--slice-package"],
        _slice_select(slices, "package_label", no_match_error),
        ["--config"],
        _slice_select(slices, "config_label", no_match_error),
        ["--target-os"],
        scg.new_fn_call("select", _TARGET_OS_SELECT),
    ]
    if tail:
        segments.append(tail)
    return segments

def _to_expr(segments):
    """Joins segments with `+` into a Starlark codegen expression.

    Args:
        segments: A `list` as returned by `swift_package_tool_args.render`.

    Returns:
        A Starlark codegen expression `struct`.
    """
    members = []
    for idx, segment in enumerate(segments):
        if idx > 0:
            members.append(scg.new_op("+"))
        members.append(segment)
    return scg.new_expr(*members)

swift_package_tool_args = struct(
    render = _render,
    to_expr = _to_expr,
)
