"""Module for retrieving values from decoded JSON."""

def _item_from_list(values, index, default = None):
    if len(values) >= index:
        return values[index]
    return default

json_utils = struct(
    item_from_list = _item_from_list,
)
