"""API for creating and managing build file declarations"""

load("@bazel_skylib//lib:sets.bzl", "sets")
load(":starlark_codegen.bzl", scg = "starlark_codegen")

def _new(kind, name, attrs = {}, comments = []):
    """Create a rule/macro declaration for a build file.

    Args:
        kind: The kind of rule/macro as a `string`.
        name: The name attribute value of the declaration as a `string`.
        attrs: Optional. The attributes for the declaration as a `dict`.
        comments: Optional. Comments that appear before the declaration as a
            `list` of `string` values.

    Returns:
        A `struct` representing a rule/macro declaration.
    """
    return struct(
        kind = kind,
        name = name,
        attrs = attrs,
        comments = comments,
        to_starlark_parts = _to_starlark_parts,
    )

def _to_starlark_parts(decl, indent):
    parts = []
    for c in decl.comments:
        parts.append(scg.indent(indent, "{}\n".format(c)))
    parts.append(scg.indent(indent, "{}(\n".format(decl.kind)))
    parts.extend(scg.attr("name", decl.name, indent + 1))

    # Sort the keys to ensure that we have a consistent output. It would be
    # ideal to output them in a manner that matches Buildifier output rules.
    keys = sorted(decl.attrs.keys())
    for key in keys:
        val = decl.attrs[key]
        parts.extend(scg.attr(key, val, indent + 1))
    parts.append(scg.indent(indent, ")"))

    return parts

def _uniq(decls):
    """Sort and check for duplicate declarations.

    Args:
        decls: A `list` of build declaration `struct` values as returned by
            `build_decls.new`.

    Returns:
        A `list` of build declarations sorted by type-name.
    """
    index_by_type_name = {}
    for decl in decls:
        key = "{kind}_{name}".format(
            kind = decl.kind,
            name = decl.name,
        )
        existing_values = index_by_type_name.get(key, default = [])
        existing_values.append(decl)
        index_by_type_name[key] = existing_values

    # Collect in type-name order
    results = []
    for type_name in sorted(index_by_type_name.keys()):
        existing_values = index_by_type_name[type_name]
        results.extend(existing_values)

    # Check for any duplicate decl names
    names = sets.make()
    for decl in results:
        name = decl.name
        if sets.contains(names, name):
            fail("A duplicate decl name was found. name: {}".format(name))
        sets.insert(names, name)

    return results

def _get(decls, name, fail_if_not_found = True):
    """Returns the declaration with the specified name.

    Args:
        decls: A `list` of `struct` values as returned by `build_decls.new`.
        name: The name of the desired declaration as a `string`.
        fail_if_not_found: Optional. A `bool` the determines whether to fail
            if the declaration is not found.

    Returns:
        The declaration `struct`, if it is found. Otherwise, it fails or
        returns `None` depending upon the value of `fail_if_not_found`.
    """
    for decl in decls:
        if decl.name == name:
            return decl
    if fail_if_not_found:
        fail("Failed to find build declaration. name:", name)
    return None

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
            scg.with_indent(indent, scg.normalize(fn_call.args[0])),
            ")",
        ]
    parts = [fn_call.fn_name, "(\n"]
    child_indent = indent + 1
    for pos_arg in fn_call.args:
        parts.extend([
            scg.indent(child_indent),
            scg.with_indent(child_indent, scg.normalize(pos_arg)),
            ",\n",
        ])
    for name in fn_call.kwargs:
        value = fn_call.kwargs[name]
        parts.extend(scg.attr(name, value, child_indent))

    parts.append(scg.indent(indent, ")"))
    return parts

build_decls = struct(
    get = _get,
    new = _new,
    new_fn_call = _new_fn_call,
    uniq = _uniq,
)
