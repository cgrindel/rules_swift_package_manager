"""Utility functions for generating Starlark code"""

_single_indent_str = "    "

def _indent(count, suffix = ""):
    return (_single_indent_str * count) + suffix

_simple_starlark_types = [
    "None",
    "bool",
    "int",
    "string",
]

def _is_simple_type(val):
    val_type = type(val)
    for t in _simple_starlark_types:
        if val_type == t:
            return True
    return False

def _to_starlark(val, indent = 0):
    # Simple types should be converted to their Stalark representation upfront.
    if _is_simple_type(val):
        return repr(val)

    # Dealing with a complex type
    out = [val]
    for _iteration in range(100):
        out, finished = _process_complex_types(out, indent)
        if finished:
            return "".join(out)
    fail("Failed to finish processing starlark for value: {}".format(val))

def _process_complex_types(out, current_indent):
    finished = True
    new_out = []
    for v in out:
        v_type = type(v)
        if v_type == "string":
            new_out.append(v)
            continue

        finished = False
        if v_type == "list":
            new_out.extend(_list_to_starlark(v, current_indent))
        elif v_type == "dict":
            new_out.extend(_dict_to_starlark(v, current_indent))
        elif v_type == "struct":
            to_starlark_fn = getattr(v, "to_starlark", None)
            if to_starlark_fn == None:
                fail("Starlark code gen received a struct without a to_starlark function.", v)
            new_out.extend(to_starlark_fn(v, current_indent))
        else:
            fail("Starlark code gen received an unsupported type.", v_type, v)

    return new_out, finished

def _list_to_starlark(val, current_indent):
    output = ["[\n"]
    for item in val:
        if _is_simple_type(item):
            item = repr(item)
        output.extend([_indent(current_indent + 1), item, ",\n"])
    output.append("]")
    return output

def _dict_to_starlark(val, current_indent):
    output = ["{\n"]
    for (k, v) in val.items():
        if _is_simple_type(k):
            k = repr(k)
        if _is_simple_type(v):
            v = repr(v)
        output.extend([_indent(current_indent + 1), k, ": ", v, ",\n"])
    output.append("}")
    return output

# def _quote(value):
#     return "\"{}\"".format(value)

# def _to_starlark(val, current_indent = 0):
#     to_str_fn = getattr(val, "to_starlark", None)
#     if to_str_fn != None:
#         str_val = to_str_fn(val, indent = indent)
#     else:
#         val_type = type(val)
#         if val_type == "string":
#             str_val = starlark_utils.quote(val)
#         elif val_type == "list":
#             pass
#         else:
#             str_val = repr(val)
#     # Adjust for indent
#     return str_val

# def _to_starlark(val, current_indent = 0):
#     to_starlark_fn = getattr(val, "to_starlark", None)
#     if to_starlark_fn != None:
#         return to_starlark_fn(val, current_indent)

#     lines = []
#     val_type = type(val)

#     if val_type == "list":
#         # The first line of a multi-line out should always have an indent of 0
#         lines.append(_line("["))
#         for item in val:
#             lines.append(_line(_to_starlark(item, current_indent + 1)))
#         lines.append(_line("]", current_indent))
#     else:
#         # Single line, no indent
#         lines.append(_line(repr(val)))

#     return lines

# def _do_to_starlark(values, current_indent):
#     pass

# def _to_starlark_results():
#     return struct(

#     )

# def _line(val, indent = 0):
#     return struct(
#         val = val,
#         indent = indent,
#     )

# def _lines_to_str(lines):

# def _list_to_str(values, double_quote_values = True, indent = "        "):
#     """Create a `string` of values that is suitable to be inserted in a Starlark list.

#     Args:
#         values: A `sequence` of `string` values.
#         double_quote_values: A `bool` indicating whether to add double quotes.
#         indent: A `string` representing the characters to prefix for each value.

#     Returns:
#         A `string` value suitable to be inserted between square brackets ([])
#         as Starlark list values.
#     """
#     if double_quote_values:
#         new_values = [_quote(value) for value in values]
#     else:
#         new_values = values

#     new_values = [
#         "{indent}{value},".format(
#             indent = indent,
#             value = value,
#         )
#         for value in new_values
#     ]
#     return "\n".join(new_values)

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
    indent = _indent,
    # quote = _quote,
    to_starlark = _to_starlark,
    # line = _line,
    # list_to_str = _list_to_str,
    # bazel_deps_str = _bazel_deps_str,
)
