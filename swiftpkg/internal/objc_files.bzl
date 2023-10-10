"""Module for retrieving info about Objective-C files."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:sets.bzl", "sets")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
load(":apple_builtin_frameworks.bzl", "apple_builtin_frameworks")

_at_import = "@import "
_at_import_len = len(_at_import)

def _parse_pound_import(line):
    line_len = len(line)

    # Find the pound sign
    pound_idx = line.find("#")
    if pound_idx < 0:
        return None
    start_idx = pound_idx + 1

    # Find import
    begin_of_import_idx = -1
    for idx in range(start_idx, line_len):
        char = line[idx]
        if char == " " or char == "\t":
            continue
        elif char == "i":
            begin_of_import_idx = idx
            break
        else:
            return None
    if not line[begin_of_import_idx:].startswith("import"):
        return None
    start_idx = begin_of_import_idx + len("import")

    # Find the opening bracket
    open_bracket_idx = -1
    for idx in range(start_idx, line_len):
        char = line[idx]
        if char == " " or char == "\t":
            continue
        elif char == "<":
            open_bracket_idx = idx
            break
        else:
            return None
    if open_bracket_idx < 0:
        return None
    framework_start_idx = open_bracket_idx + 1

    # Find the first slash (/)
    slash_idx = -1
    for idx in range(open_bracket_idx, line_len):
        char = line[idx]
        if char == "/":
            slash_idx = idx
    if slash_idx < 0:
        return None

    return line[framework_start_idx:slash_idx]

def _parse_at_import(line):
    import_idx = line.find(_at_import)
    if import_idx < 0:
        return None
    start_idx = import_idx + _at_import_len
    line_len = len(line)

    framework_start_idx = -1
    framework_end_idx = -1
    for idx in range(start_idx, line_len):
        char = line[idx]
        if char == " " or char == "\t":
            continue
        elif char == ";":
            framework_end_idx = idx
            break
        elif framework_start_idx < 0:
            framework_start_idx = idx

    if framework_start_idx < 0 or framework_end_idx < 0:
        return None
    return line[framework_start_idx:framework_end_idx]

# def _parse_for_imported_framework(line):
#     """Parse a single line of text looking for a framework import.

#     Args:
#         line: The line to be parsed as a `string`.

#     Returns:
#         The name of the imported framework as a `string`, if a framework
#         import is found. Otherwise, it returns `None`.
#     """
#     if line == None or line == "":
#         return None

#     def _verify(name):
#         if sets.contains(apple_builtin_frameworks.all, name):
#             return name
#         else:
#             return None

#     framework = _parse_pound_import(line)
#     if framework != None:
#         return _verify(framework)
#     framework = _parse_at_import(line)
#     if framework != None:
#         return _verify(framework)
#     return None

def _parse_for_import(line):
    """Parse a single line of text looking for a framework import.

    Args:
        line: The line to be parsed as a `string`.

    Returns:
        The name of the imported framework as a `string`, if a framework
        import is found. Otherwise, it returns `None`.
    """
    if line == None or line == "":
        return None
    framework = _parse_pound_import(line)
    if framework != None:
        return framework
    framework = _parse_at_import(line)
    if framework != None:
        return framework
    return None

def _collect_imports_for_src(repository_ctx, src_path):
    imports = []
    contents = repository_ctx.read(src_path)
    lines = contents.splitlines()
    for line in lines:
        imp = _parse_for_import(line)
        if imp != None:
            imports.append(imp)
    return imports

# def _collect_frameworks_for_src(repository_ctx, src_path):
#     frameworks = []
#     contents = repository_ctx.read(src_path)

#     lines = contents.splitlines()
#     for line in lines:
#         imported_framework = _parse_for_imported_framework(line)
#         if imported_framework != None:
#             frameworks.append(imported_framework)
#     return frameworks

def _collect_src_info(repository_ctx, root_path, srcs):
    """Collect all of the Apple built-in frameworks imported by the specified \
    source files.

    Args:
        repository_ctx: An instance of `repository_ctx`.
        root_path: The parent path for the source files as a `string`.
        srcs: A `list` of source file paths relative to the `root_path`.

    Returns:
        A `list` of the imported Apple built-in frameworks.
    """
    frameworks = sets.make()
    other_imports = sets.make()
    for src in srcs:
        src_path = paths.join(root_path, src)
        imports = _collect_imports_for_src(repository_ctx, src_path)
        for imp in imports:
            if sets.contains(apple_builtin_frameworks.all, imp):
                sets.insert(frameworks, imp)
            else:
                sets.insert(other_imports, imp)
    return struct(
        frameworks = sorted(sets.to_list(frameworks)),
        other_imports = sorted(sets.to_list(other_imports)),
    )

# def _collect_builtin_frameworks(repository_ctx, root_path, srcs):
#     """Collect all of the Apple built-in frameworks imported by the specified \
#     source files.

#     Args:
#         repository_ctx: An instance of `repository_ctx`.
#         root_path: The parent path for the source files as a `string`.
#         srcs: A `list` of source file paths relative to the `root_path`.

#     Returns:
#         A `list` of the imported Apple built-in frameworks.
#     """
#     frameworks = sets.make()
#     for src in srcs:
#         src_path = paths.join(root_path, src)
#         src_frameworks = _collect_frameworks_for_src(repository_ctx, src_path)

#         for sf in src_frameworks:
#             sets.insert(frameworks, sf)
#     return sorted(sets.to_list(frameworks))

def _has_objc_srcs(srcs):
    """Determines whether any of the provide paths are Objective-C files.

    Args:
        srcs: A `list` of file paths (`string`).

    Returns:
        A `bool` indicating whether any of the source files are Objective-C
        files.
    """
    return lists.contains(srcs, lambda x: x.endswith(".m") or x.endswith(".mm"))

objc_files = struct(
    # collect_builtin_frameworks = _collect_builtin_frameworks,
    collect_src_info = _collect_src_info,
    has_objc_srcs = _has_objc_srcs,
    # Public for testing purposes
    # parse_for_imported_framework = _parse_for_imported_framework,
)
