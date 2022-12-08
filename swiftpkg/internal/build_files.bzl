"""Module for defining and generating Bazel build files."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(":build_decls.bzl", "build_decls")
load(":load_statements.bzl", "load_statements")
load(":starlark_codegen.bzl", scg = "starlark_codegen")

def _new(load_stmts = [], decls = []):
    """Create a `struct` that represents the parts of a Bazel build file.

    Args:
        load_stmts: A `list` of load statement `struct` values as returned
            by `load_statements.new`.
        decls: A `list` of declaration `struct` values as returned by
            `build_decls.new`.

    Returns:
        A `struct` representing parts of a Bazel  build file.
    """
    if len(load_stmts) == 0 and len(decls) == 0:
        fail("""\
Attempted to create a build file with no load statements or declarations.\
""")
    return struct(
        load_stmts = load_stmts,
        decls = decls,
        to_starlark_parts = _to_starlark_parts,
    )

def _to_starlark_parts(build_file, indent):
    parts = []
    for load_stmt in build_file.load_stmts:
        parts.extend([scg.with_indent(indent, load_stmt), "\n"])
    for decl in build_file.decls:
        parts.extend(["\n", scg.with_indent(indent, decl), "\n"])
    return parts

def _merge(*bld_files):
    """Merge build file `struct` values into a single value.

    The load statements will be sorted and deduped. The targets will be sorted
    by type and name.

    Args:
        *bld_files: A `sequence` of build file declaration `struct` values
            as returned by `build_files.new`.

    Returns:
        A merged build file declaration `struct`.
    """
    if len(bld_files) == 0:
        fail("Attempted to merge build files, but none were provided.")

    load_stmts = []
    decls = []
    for bf in bld_files:
        load_stmts.extend(bf.load_stmts)
        decls.extend(bf.decls)
    load_stmts = load_statements.uniq(load_stmts)
    decls = build_decls.uniq(decls)
    return _new(
        load_stmts = load_stmts,
        decls = decls,
    )

def _write(repository_ctx, build_file, path):
    bld_file_path = paths.join(path, "BUILD.bazel")
    repository_ctx.file(
        bld_file_path,
        content = scg.to_starlark(build_file),
        executable = False,
    )

build_files = struct(
    new = _new,
    merge = _merge,
    write = _write,
)
