"""API for creating and managing build file declarations"""

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

build_decls = struct(
    new = _new,
)
