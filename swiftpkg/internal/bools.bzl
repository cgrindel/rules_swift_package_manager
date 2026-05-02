"""Helpers for working with bool values."""

def _to_shell_str(value):
    """Converts a value to its lowercase shell-bool representation.

    Shell scripts in this project compare flag values with
    `[[ ${var} == "true" ]]`, so Starlark bools must be serialized as
    `"true"` / `"false"` (not Python's `"True"` / `"False"`).

    Non-bool inputs fall through Starlark's standard truthiness rules
    (non-empty containers and non-zero numbers are truthy; empty / zero
    / None are falsy).

    Args:
        value: Any value; evaluated for truthiness.

    Returns:
        `"true"` if `value` is truthy, otherwise `"false"`.
    """
    return "true" if value else "false"

bools = struct(
    to_shell_str = _to_shell_str,
)
