"""Utility functions for generating Starlark code"""

_single_indent_str = "    "

# MARK: - Simple Type Detection

_simple_starlark_types = [
    "NoneType",
    "bool",
    "int",
    "string",
]

def _is_simple_type(val):
    """Determines if the specified value is 'simple' Starlark codegen type.

    Simple types are converted to strings using the `repr()` function.

    Args:
        val: The value to evaluate.

    Returns:
        A `bool` specifying whether the type is considered simple.
    """
    val_type = type(val)
    for t in _simple_starlark_types:
        if val_type == t:
            return True
    return False

# MARK: - Indent

def _indent(count, suffix = ""):
    """Generate the proper indent string based upon the count.

    Args:
        count: An `int` representing the number of indents to be generated.
        suffix: Optional. A `string` that is appended to the generated indents.

    Returns:
        A `string` with the specified number of indets.
    """
    return (_single_indent_str * count) + suffix

def _with_indent(indent, value):
    """Wraps a value with a directive to evaluate it at a specified indent level.

    Args:
        indent: The indent level as an `int`.
        value: The value to be wrapped.

    Returns:
        A `struct` that encapsulates the value and the indent information.
    """
    return struct(
        with_indent = indent,
        wrapped_value = value,
    )

# MARK: - Normalize

def _normalize(val):
    """Attempts to simplify the value, if possible. Otherwise, returns the value unchanged.

    Args:
        val: The value to evaluate.

    Returns:
        A `string` if the value is a simple type. Otherwise, the original value.
    """
    if _is_simple_type(val):
        return repr(val)
    return val

# MARK: - Generate Starlark Code

def _to_starlark(val):
    """Generates Starlark code from the provided value.

    Args:
        val: The value to evaluate.

    Returns:
        A `string` of Starlark code.
    """

    # Simple types should be converted to their Stalark representation upfront.
    if _is_simple_type(val):
        return repr(val)

    # Dealing with a complex type
    out = [val]
    for _iteration in range(100):
        out, finished = _process_complex_types(out)
        if finished:
            return "".join(out)
    fail("Failed to finish processing starlark for value: {}".format(val))

def _process_complex_types(out):
    finished = True
    new_out = []
    for v in out:
        v_type = type(v)

        # Check for a with_indent struct and get its indent value and process
        # its wrapped value
        current_indent = 0
        if v_type == "struct":
            with_indent_val = getattr(v, "with_indent", None)
            if with_indent_val != None:
                current_indent = with_indent_val
                v = v.wrapped_value
                v_type = type(v)

        if v_type == "string":
            new_out.append(v)
            continue

        # If it is not a string, then we need process the output at least one
        # more time
        finished = False

        if v_type == "list":
            new_out.extend(_process_list(v, current_indent))
        elif v_type == "dict":
            new_out.extend(_process_dict(v, current_indent))
        elif v_type == "struct":
            to_starlark_fn = getattr(v, "to_starlark_parts", None)
            if to_starlark_fn == None:
                fail("Starlark code gen received a struct without a to_starlark_parts function.", v)
            new_out.extend(to_starlark_fn(v, current_indent))
        else:
            fail("Starlark code gen received an unsupported type.", v_type, v)

    return new_out, finished

def _process_list(val, current_indent):
    val_len = len(val)
    if val_len == 0:
        return ["[]"]
    elif val_len == 1:
        return ["[", _with_indent(current_indent, _normalize(val[0])), "]"]

    child_indent = current_indent + 1
    output = ["[\n"]
    for item in val:
        item = _normalize(item)
        output.extend([
            _indent(child_indent),
            _with_indent(child_indent, item),
            ",\n",
        ])
    output.extend([_indent(current_indent), "]"])
    return output

def _process_dict(val, current_indent):
    if len(val) == 0:
        return ["{}"]

    child_indent = current_indent + 1
    output = ["{\n"]
    for (k, v) in val.items():
        k = _normalize(k)
        v = _normalize(v)
        output.extend([
            _indent(child_indent),
            k,
            ": ",
            _with_indent(child_indent, v),
            ",\n",
        ])
    output.extend([_indent(current_indent), "}"])
    return output

# MARK: - Attribute

def _new_attr(name, value, indent):
    """Generates the Starlark codegen parts that represents an attribute value.

    Args:
        name: The attribute name as a `string`.
        value: The attribute value as any type supported by Starlark codegen.
        indent: The number of indents to be used for the attribute.

    Returns:
        A `list` of Starlark codegen parts.
    """
    value = _normalize(value)
    return [
        _indent(indent),
        "{} = ".format(name),
        _with_indent(indent, value),
        ",\n",
    ]

# MARK: - Function Call

def _new_fn_call(fn_name, *args, **kwargs):
    """Create a function call.

    Args:
        fn_name: The name of the function as a `string`.
        *args: Positional arguments for the function call.
        **kwargs: Named arguments for the function call.

    Returns:
        A `struct` representing a Starlark function call.
    """
    return struct(
        fn_name = fn_name,
        args = args,
        kwargs = kwargs,
        to_starlark_parts = _fn_call_to_starlark_parts,
        # Support being used as a declaration (e.g. exports_files)
        kind = "_function",
        name = fn_name,
    )

def _fn_call_to_starlark_parts(fn_call, indent):
    args_len = len(fn_call.args)
    kwargs_len = len(fn_call.kwargs)
    if args_len == 0 and kwargs_len == 0:
        return [fn_call.fn_name, "()"]
    if args_len == 1 and kwargs_len == 0:
        return [
            fn_call.fn_name,
            "(",
            _with_indent(indent, _normalize(fn_call.args[0])),
            ")",
        ]
    parts = [fn_call.fn_name, "(\n"]
    child_indent = indent + 1
    for pos_arg in fn_call.args:
        parts.extend([
            _indent(child_indent),
            _with_indent(child_indent, _normalize(pos_arg)),
            ",\n",
        ])
    for name in fn_call.kwargs:
        value = fn_call.kwargs[name]
        parts.extend(_new_attr(name, value, child_indent))

    parts.append(_indent(indent, ")"))
    return parts

# MARK: - Operator

def _new_op(operator):
    """Create an operator.

    Args:
        operator: The operator as a `string`.

    Returns:
        A Starlark codegen `struct` representing the operator.
    """
    return struct(
        operator = operator,
        to_starlark_parts = _op_to_starlark_parts,
    )

# buildifier: disable=unused-variable
def _op_to_starlark_parts(op, indent):
    return [op.operator]

# MARK: - Expression

def _new_expr(first, *others):
    """Create an expression with one or more members

    Args:
        first: The first member of the expression.
        *others: Any additional members of the expression.

    Returns:
        A Starlark codegen `struct` representing the expression.
    """
    members = [first]
    members.extend(others)
    return struct(
        members = members,
        to_starlark_parts = _expr_to_starlark_parts,
    )

# buildifier: disable=unused-variable
def _expr_to_starlark_parts(expr, indent):
    last_idx = len(expr.members) - 1
    parts = []
    for (idx, m) in enumerate(expr.members):
        parts.append(_with_indent(indent, _normalize(m)))
        if idx != last_idx:
            parts.append(" ")
    return parts

# MARK: - Escape String

def _normalize_define_value(value):
    """Ensures that the specified value is properly formatted as a `defines` \
    value.

    Args:
        value: The `string` to normalize.

    Returns:
        A `string` that is formatted properly to be a `defines` value.
    """
    return value.replace(" ", "\\ ")

# MARK: - API Definition

starlark_codegen = struct(
    indent = _indent,
    new_attr = _new_attr,
    new_expr = _new_expr,
    new_fn_call = _new_fn_call,
    new_op = _new_op,
    normalize = _normalize,
    to_starlark = _to_starlark,
    with_indent = _with_indent,
    normalize_define_value = _normalize_define_value,
)
