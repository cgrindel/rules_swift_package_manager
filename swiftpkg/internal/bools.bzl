"""Helpers for working with bool values."""

def _to_shell_str(value):
    """Converts a bool to its lowercase shell representation.

    Shell scripts in this project compare flag values with
    `[[ ${var} == "true" ]]`, so Starlark bools must be serialized as
    `"true"` / `"false"` (not Python's `"True"` / `"False"`).

    Args:
        value: A bool.

    Returns:
        `"true"` if `value` is truthy, otherwise `"false"`.
    """
    return "true" if value else "false"

bools = struct(
    to_shell_str = _to_shell_str,
)
