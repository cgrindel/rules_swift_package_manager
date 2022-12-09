"""Module for managing Starlark `list` values."""

def _compact(items):
    """Returns the provide items with any `None` values removed.

    Args:
        items: A `list` of items to evaluate.

    Returns:
        A `list` of items with the `None` values removed.
    """
    new_items = []
    for item in items:
        if item != None:
            new_items.append(item)
    return new_items

def _contains(items, target):
    """Determines if the provide value is found in a list.

    Args:
        items: A `list` of items to evaluate.
        target: The item that may be contained in the items list.

    Returns:
        A `bool` indicating whether the target item was found in the list.
    """
    for item in items:
        if item == target:
            return True
    return False

lists = struct(
    compact = _compact,
    contains = _contains,
)
