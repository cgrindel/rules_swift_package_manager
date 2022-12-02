"""Utility functions for generating Starlark code"""

def _quote(value):
    return "\"{}\"".format(value)

def _list_to_str(values, double_quote_values = True, indent = "        "):
    """Create a `string` of values that is suitable to be inserted in a Starlark list.

    Args:
        values: A `sequence` of `string` values.
        double_quote_values: A `bool` indicating whether to add double quotes.
        indent: A `string` representing the characters to prefix for each value.

    Returns:
        A `string` value suitable to be inserted between square brackets ([])
        as Starlark list values.
    """
    if double_quote_values:
        new_values = [_quote(value) for value in values]
    else:
        new_values = values

    new_values = [
        "{indent}{value},".format(
            indent = indent,
            value = value,
        )
        for value in new_values
    ]
    return "\n".join(new_values)

# def _bazel_deps_str(pkg_name, target_deps):
#     """Create deps list string suitable for injection into a module template.

#     Args:
#         pkg_name: The name of the Swift package as a `string`.
#         target_deps: A `list` of the target's dependencies as target
#                      references (`references.create_target_ref()`).

#     Returns:
#         A `string` value.
#     """
#     target_labels = []
#     for target_ref in target_deps:
#         target_labels.append(_target_ref_str(pkg_name, target_ref))
#     return _bazel_list_str(target_labels, double_quote_values = True)

starlark_utils = struct(
    quote = _quote,
    list_to_str = _list_to_str,
    # bazel_deps_str = _bazel_deps_str,
)
