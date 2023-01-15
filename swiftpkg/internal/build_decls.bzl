"""API for creating and managing build file declarations"""

load("@bazel_skylib//lib:sets.bzl", "sets")
load(":starlark_codegen.bzl", scg = "starlark_codegen")

def _new(kind, name, attrs = {}, comments = []):
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
    for decl in decls:
        if decl.name == name:
            return decl
    if fail_if_not_found:
        fail("Failed to find build declaration. name:", name)
    return None

def _new_glob(
        include,
        exclude = None,
        exclude_directories = None,
        allow_empty = None):
    return struct(
        include = include,
        exclude = exclude,
        exclude_directories = exclude_directories,
        allow_empty = allow_empty,
        to_starlark_parts = _glob_to_starlark_parts,
    )

def _glob_to_starlark_parts(glob, indent):
    parts = ["glob("]
    parts.append(scg.with_indent(indent, glob.include))
    parts.append(")")
    return parts

build_decls = struct(
    get = _get,
    new = _new,
    new_glob = _new_glob,
    uniq = _uniq,
)
