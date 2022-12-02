"""Module for defining and generating Bazel build files."""

# load("@bazel_skylib//lib:sets.bzl", "sets")
# load(":references.bzl", refs = "references")

# # MARK: - Load Statement

# def _load_statement(location, *symbols):
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
#         new_load_stmt = _load_statement(location, *symbols)
#         results.append(new_load_stmt)

#     return results

# # MARK: - Target

# def _target(type, name, declaration):
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

# def _create(load_statements = [], targets = []):
#     """Create a `struct` that represents the parts of a Bazel build file.

#     Args:
#         load_statements: A `list` of load statement `struct` values as returned
#                          by `build_declarations.load_statement`.
#         targets: A `list` of target `struct` values as returned by
#                  `build_declarations.target`.

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
#                      as returned by `build_declarations.create`.

#     Returns:
#         A merged build file declaration `struct`.
#     """
#     load_statements = []
#     targets = []
#     for bd in build_decls:
#         load_statements.extend(bd.load_statements)
#         targets.extend(bd.targets)
#     return _create(
#         load_statements = load_statements,
#         targets = targets,
#     )

# # MARK: - Starlark Code Generation

# def _generate_load_statement(load_stmt):
#     """Generate a Starlark load statement from a load statement `struct`.

#     Args:
#         load_stmt: A load statement `struct` as returned by
#                    `build_declarations.load_statement`.

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

# def _generate_build_file_content(build_decl):
#     """Generate Bazel build file content from a build file declaration `struct`.

#     Args:
#         build_decl: A build file declaration `struct` as returned by
#                     `build_declarations.create`.

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

# def _write_build_file(repository_ctx, path, build_decl):
#     """Write a Bazel build file from a build declaration.

#     Args:
#         repository_ctx: A Bazel `repository_ctx` instance.
#         path: The path where to write the build file content as a `string`.
#         build_decl: A build declaration `struct` as returned by
#                     `build_declarations.create`.
#     """
#     content = _generate_build_file_content(build_decl)
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

# def _quote_str(value):
#     return "\"{}\"".format(value)

# def _bazel_list_str(values, double_quote_values = True, indent = "        "):
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
#         new_values = [_quote_str(value) for value in values]
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

# build_declarations = struct(
#     # Target Declaration
#     target = _target,
#     # Load Statement
#     load_statement = _load_statement,
#     # Build Declaration
#     create = _create,
#     merge = _merge,
#     # Build File Generation
#     generate_build_file_content = _generate_build_file_content,
#     write_build_file = _write_build_file,
#     bazel_list_str = _bazel_list_str,
#     bazel_deps_str = _bazel_deps_str,
#     quote_str = _quote_str,
# )
