"""Utility functions for generating Starlark code"""

_single_indent_str = "    "

def _indent(count, suffix = ""):
    return (_single_indent_str * count) + suffix

def attr(name, value, indent):
    return [_indent(indent), "{} = ".format(name), _normalize(value), ",\n"]

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

def _normalize(val):
    if _is_simple_type(val):
        return repr(val)
    return val

def _to_starlark(val):
    # Simple types should be converted to their Stalark representation upfront.
    if _is_simple_type(val):
        return repr(val)

    # Dealing with a complex type
    out = [val]
    current_indent = 0
    for _iteration in range(100):
        out, finished = _process_complex_types(out, current_indent)
        if finished:
            return "".join(out)
        current_indent = current_indent + 1
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
            new_out.extend(_list(v, current_indent))
        elif v_type == "dict":
            new_out.extend(_dict(v, current_indent))
        elif v_type == "struct":
            to_starlark_fn = getattr(v, "to_starlark_parts", None)
            if to_starlark_fn == None:
                fail("Starlark code gen received a struct without a to_starlark_parts function.", v)
            new_out.extend(to_starlark_fn(v, current_indent))
        else:
            fail("Starlark code gen received an unsupported type.", v_type, v)

    return new_out, finished

def _list(val, current_indent):
    if len(val) == 0:
        return ["[]"]

    output = ["[\n"]
    for item in val:
        item = _normalize(item)
        output.extend([_indent(current_indent + 1), item, ",\n"])
    output.extend([_indent(current_indent), "]"])
    return output

def _dict(val, current_indent):
    if len(val) == 0:
        return ["{}"]

    output = ["{\n"]
    for (k, v) in val.items():
        k = _normalize(k)
        v = _normalize(v)
        output.extend([_indent(current_indent + 1), k, ": ", v, ",\n"])
    output.extend([_indent(current_indent), "}"])
    return output

starlark_utils = struct(
    indent = _indent,
    to_starlark = _to_starlark,
    normalize = _normalize,
    attr = attr,
)
