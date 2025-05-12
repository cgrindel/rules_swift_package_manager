"""Module for Bazel compilation modes."""

def _label(name):
    """Returns the condition label for the Bazel compilation mode name.

    Args:
        name: The Bazel compilation mode name as a `string`.

    Returns:
        The condition label as a `string`.
    """
    return "@rules_swift_package_manager//config_settings/bazel/compilation_mode:{}".format(name)

compilation_modes = struct(
    debug = "dbg",
    optimized = "opt",
    fast = "fastbuild",
    all_values = [
        "dbg",
        "opt",
        "fastbuild",
    ],
    label = _label,
)
