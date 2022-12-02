"""Definition for collection_results module."""

def _create(declarations, count):
    """Creates a collection result `struct`.

    Args:
        declarations: The declarations that were collected.
        count: The number of tokens that were collected.

    Returns:
        A `struct` representing the data that was collected.
    """
    return struct(
        declarations = declarations,
        count = count,
    )

collection_results = struct(
    new = _create,
)
