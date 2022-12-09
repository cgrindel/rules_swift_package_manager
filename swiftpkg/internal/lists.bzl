"""Module for managing Starlark `list` values."""

def _compact(items):
    new_items = []
    for item in items:
        if item != None:
            new_items.append(item)
    return new_items

lists = struct(
    compact = _compact,
)
