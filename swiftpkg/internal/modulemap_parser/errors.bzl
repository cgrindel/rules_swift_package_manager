"""Definition for errors module."""

def _create_error(msg, child_errors = []):
    """Create an error `struct`.

    Args:
        msg: A `string` describing the error.
        child_errors: A `list` of any errors that are related to this error.

    Returns:
        Returns a `struct` representing the error.
    """
    return struct(
        msg = msg,
        child_errors = child_errors,
    )

# MARK: - Namespace

errors = struct(
    new = _create_error,
)
