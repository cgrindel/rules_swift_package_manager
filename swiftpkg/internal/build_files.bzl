"""Module for defining and generating Bazel build files."""

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
    return struct(
        load_stmts = new_load_stmts,
        decls = new_decls,
    )

def _merge(*bld_files):
    """Merge build file `struct` values into a single value.

    The load statements will be sorted and deduped. The targets will be sorted
    by type and name.

    Args:
        *build_files: A `sequence` of build file declaration `struct` values
            as returned by `build_files.new`.

    Returns:
        A merged build file declaration `struct`.
    """
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

build_files = struct(
    new = _new,
    merge = _merge,
)

# load("@bazel_skylib//lib:sets.bzl", "sets")
# load(":references.bzl", refs = "references")

# # MARK: - Load Statement

# def _new_load_stmt(location, *symbols):
#     """Create a load statement `struct`.

#     The list of symbols will be sorted and uniquified.

#     Args:
#         location: A `string` representing the location of a Starlark file.
#         *symbols: A `sequence` of symbols to be loaded from the location.

#     Returns:
#         A `struct` that includes the location and the cleaned up symbols.
#     """
#     if len(symbols) < 1:
#         fail("""\
# Expected at least one symbol to be specified. location: {location}\
# """.format(location = location))

#     # Get a unique set
#     symbols_set = sets.make(symbols)
#     new_symbols = sorted(sets.to_list(symbols_set))
#     return struct(
#         location = location,
#         symbols = new_symbols,
#     )

# def _clean_up_load_statements(load_statements):
#     index_by_location = {}
#     for load_stmt in load_statements:
#         location = load_stmt.location
#         existing_values = index_by_location.get(location, default = [])
#         existing_values.append(load_stmt)
#         index_by_location[location] = existing_values

#     # Collect results in location-sorted order
#     results = []
#     for location in sorted(index_by_location.keys()):
#         existing_values = index_by_location[location]
#         symbols = []
#         for load_stmt in existing_values:
#             symbols.extend(load_stmt.symbols)
#         new_load_stmt = _new_load_stmt(location, *symbols)
#         results.append(new_load_stmt)

#     return results

# # MARK: - Target

# def _new_decl(type, name, declaration):
#     """Create a target `struct`.

#     Args:
#         type: A `string` specifying the rule/macro type.
#         name: A `string` representing the target name.
#         declaration: The Starlark code for the declaration as a `string`.

#     Returns:
#         A `struct` that represents a target declaration in a build file.
#     """
#     return struct(
#         type = type,
#         name = name,
#         declaration = declaration,
#     )

# def _clean_up_targets(targets):
#     index_by_type_name = {}
#     for target in targets:
#         key = "{type}_{name}".format(
#             type = target.type,
#             name = target.name,
#         )
#         existing_values = index_by_type_name.get(key, default = [])
#         existing_values.append(target)
#         index_by_type_name[key] = existing_values

#     # Collect in type-name order
#     results = []
#     for type_name in sorted(index_by_type_name.keys()):
#         existing_values = index_by_type_name[type_name]
#         results.extend(existing_values)

#     # Check for any duplicate target names
#     names = sets.make()
#     for target in results:
#         name = target.name
#         if sets.contains(names, name):
#             fail("A duplicate target name was found. name: {}".format(name))
#         sets.insert(names, name)

#     return results

# # MARK: - Build Declaration

# def _new(load_statements = [], targets = []):
#     """Create a `struct` that represents the parts of a Bazel build file.

#     Args:
#         load_statements: A `list` of load statement `struct` values as returned
#                          by `build_files.load_statement`.
#         targets: A `list` of target `struct` values as returned by
#                  `build_files.target`.

#     Returns:
#         A `struct` representing parts of a Bazel  build file.
#     """
#     new_load_stmts = _clean_up_load_statements(load_statements)
#     new_targets = _clean_up_targets(targets)
#     return struct(
#         load_statements = new_load_stmts,
#         targets = new_targets,
#     )

# def _merge(*build_decls):
#     """Merge build file `struct` values into a single value.

#     The load statements will be sorted and deduped. The targets will be sorted
#     by type and name.

#     Args:
#         *build_decls: A `sequence` of build file declaration `struct` values
#                      as returned by `build_files.create`.

#     Returns:
#         A merged build file declaration `struct`.
#     """
#     load_statements = []
#     targets = []
#     for bd in build_decls:
#         load_statements.extend(bd.load_statements)
#         targets.extend(bd.targets)
#     return _new(
#         load_statements = load_statements,
#         targets = targets,
#     )

# # MARK: - Starlark Code Generation

# def _generate_load_statement(load_stmt):
#     """Generate a Starlark load statement from a load statement `struct`.

#     Args:
#         load_stmt: A load statement `struct` as returned by
#                    `build_files.load_statement`.

#     Returns:
#         A Starlark load statement `string` value.
#     """
#     symbols_str = ", ".join([
#         "\"{}\"".format(s)
#         for s in load_stmt.symbols
#     ])
#     return """load("{location}", {symbols})""".format(
#         location = load_stmt.location,
#         symbols = symbols_str,
#     )

# def _as_str(build_decl):
#     """Generate Bazel build file content from a build file declaration `struct`.

#     Args:
#         build_decl: A build file declaration `struct` as returned by
#                     `build_files.create`.

#     Returns:
#         A `string` containing valid Starlark code that can be used as Bazel
#         build file content.
#     """
#     load_statements = "\n".join([
#         _generate_load_statement(ls)
#         for ls in build_decl.load_statements
#     ])
#     target_decls = "\n".join([
#         t.declaration + ("" if t.declaration[-1] == "\n" else "\n")
#         for t in build_decl.targets
#     ])
#     parts = []
#     if load_statements != "":
#         load_statements += ("" if load_statements[-1] == "\n" else "\n")
#         parts.append(load_statements)
#     if target_decls != "":
#         parts.append(target_decls)
#     return "\n".join(parts)

# def _write(repository_ctx, path, build_decl):
#     """Write a Bazel build file from a build declaration.

#     Args:
#         repository_ctx: A Bazel `repository_ctx` instance.
#         path: The path where to write the build file content as a `string`.
#         build_decl: A build declaration `struct` as returned by
#                     `build_files.create`.
#     """
#     content = _as_str(build_decl)
#     repository_ctx.file(path, content = content, executable = False)

# def _target_ref_str(pkg_name, target_ref):
#     """Create a valid Bazel target reference `string`.

#     Args:
#         pkg_name: The name of the package where the reference will be written as
#                   a `string`.
#         target_ref: A reference `string` as created by
#                     `references.create_target_ref()`.

#     Returns:
#         A Bazel target reference `string`.
#     """
#     _rtype, pname, tname = refs.split(target_ref)
#     if pname == pkg_name:
#         return ":%s" % (tname)
#     return "//%s:%s" % (pname, tname)

# build_files = struct(
#     # Target Declaration
#     new_decl = _new_decl,
#     # Load Statement
#     new_load_stmt = _new_load_stmt,
#     # Build File
#     new = _new,
#     merge = _merge,
#     # Build File Content
#     as_str = _as_str,
#     write = _write,
# )
