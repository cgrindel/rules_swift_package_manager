"""Module for Swift file operations."""

load("@bazel_skylib//lib:paths.bzl", "paths")

def _has_objc_directive(repository_ctx, path):
    """Determines whether the specified file contains any `@objc` or \
    `@objcMembers` directives indicating that the Swift file will be consumed \
    by Objective-C code.

    Args:
        repository_ctx: A `repository_ctx` instance.
        path: The path to a file as a `string`.

    Returns:
        A `bool` indicating whether the file contains an Objective-C directive.
    """
    contents = repository_ctx.read(path)
    result = contents.find("@objc")
    return result >= 0

def _find_import(contents, target_import, start_idx = 0):
    contents_len = len(contents)
    target_stmt = "import {}".format(target_import)
    target_stmt_len = len(target_stmt)

    for _ in range(start_idx, contents_len):
        imp_start_idx = contents.find(target_stmt, start_idx)
        if imp_start_idx < 0:
            return None

        # Include the previous char; looking for word boundary
        frag_start = imp_start_idx
        if frag_start > 0:
            frag_start -= 1

        # Include the next char; looking for word boundary
        imp_end_idx = imp_start_idx + target_stmt_len
        start_idx = imp_end_idx
        frag_end = imp_end_idx + 1
        if frag_end > contents_len:
            # We are at the end of the contents
            frag_end -= 1
        fragment = contents[frag_start:frag_end]
        if fragment.strip() == target_stmt:
            return _new_range(start = imp_start_idx, end = imp_end_idx)

    return None

def _new_range(start, end):
    return struct(
        start = start,
        end = end,
    )

def _look_ahead(contents, idx, value):
    look_head_len = len(value)
    look_ahead_idx = idx + look_head_len
    if look_ahead_idx > len(contents):
        return -1
    look_ahead = contents[idx:look_ahead_idx]
    if look_ahead == value:
        return look_ahead_idx
    return -1

_multiline_str_delim = "\"\"\""

def _collect_string_literal(contents, idx):
    # Check for multiline string (""")
    start_idx = _look_ahead(contents, idx, _multiline_str_delim)
    if start_idx >= 0:
        multiline = True
    else:
        multiline = False
        start_idx = idx + 1

    escape = False
    for sidx in range(start_idx, len(contents)):
        char = contents[sidx]
        if char == "\"" and not escape:
            if multiline:
                la_idx = _look_ahead(contents, sidx, _multiline_str_delim)
                if la_idx >= 0:
                    return la_idx
            else:
                return sidx + 1
        elif char == "\\":
            escape = True
        else:
            escape = False

    fail("Did not find the end of the string literal starting at {}.".format(
        idx,
    ))

def _collect_single_line_comment(contents, idx):
    # We know that idx is pointing at //
    start_idx = idx + 2
    for sidx in range(start_idx, len(contents)):
        char = contents[sidx]
        if char == "\n":
            return sidx + 1
    fail("Did not find the end of single line comment starting at {}.".format(
        idx,
    ))

def _collect_multiline_comment(contents, idx):
    # We know that idx is pointing at /*
    start_idx = idx + 2
    for sidx in range(start_idx, len(contents)):
        char = contents[sidx]
        if char == "*":
            la_idx = _look_ahead(contents, sidx, "*/")
            if la_idx >= 0:
                return la_idx
    fail("Did not find the end of multi-line comment starting at {}.".format(
        idx,
    ))

def _collect_conditional_compilation(contents, idx):
    # Conditional compilation blocks can be nested. We will process until
    # block level is at 0.
    block_level = 1

    # We know that idx is pointing at #if
    start_idx = idx + 3
    for sidx in range(start_idx, len(contents)):
        char = contents[sidx]
        if char == "#":
            if _look_ahead(contents, sidx, "#if") >= 0:
                block_level += 1
            else:
                la_idx = _look_ahead(contents, sidx, "#endif")
                if la_idx >= 0:
                    block_level -= 1
                    if block_level == 0:
                        return la_idx

    fail("""\
Did not find the end of the conditional compilation block starting at {}.\
""".format(idx))

def _is_code(contents, target_idx):
    skip_to = -1
    for idx in range(0, len(contents)):
        if skip_to == idx:
            # Need to reset the skip_to before the next check.
            skip_to = -1
        if idx == target_idx:
            # If we are not skipping ahead, then it is a valid code location.
            return skip_to < 0
        if skip_to > idx:
            continue
        elif skip_to >= 0:
            fail("Somehow skip_to is behind. idx: {idx}, skip_to: {skip_to}".format(
                idx = idx,
                skip_to = skip_to,
            ))
        char = contents[idx]
        if char == "\"":
            skip_to = _collect_string_literal(contents, idx)
        elif char == "/":
            if _look_ahead(contents, idx, "//") >= 0:
                skip_to = _collect_single_line_comment(contents, idx)
            elif _look_ahead(contents, idx, "/*") >= 0:
                skip_to = _collect_multiline_comment(contents, idx)
        elif char == "#":
            if _look_ahead(contents, idx, "#if") >= 0:
                skip_to = _collect_conditional_compilation(contents, idx)

    return False

def _has_import(contents, target_import):
    """Determines whether a string contains a Swift import statement for module.

    Args:
        contents: A `string` value to be evaluated.
        target_import: The name of the imported module as a `string`.

    Returns:
        A `bool` indicating whether an import statement for the module was found.
    """
    start_idx = 0
    for _ in range(len(contents)):
        import_range = _find_import(contents, target_import, start_idx = start_idx)
        if import_range == None:
            return False
        if _is_code(contents, import_range.start):
            return True
        start_idx = import_range.end
    return False

# def _has_import(contents, target_import):
#     """Determines whether a string contains a Swift import statement for module.

#     Args:
#         contents: A `string` value to be evaluated.
#         target_import: The name of the imported module as a `string`.

#     Returns:
#         A `bool` indicating whether an import statement for the module was found.
#     """
#     contents_len = len(contents)
#     start_idx = 0
#     target_stmt = "import {}".format(target_import)
#     target_stmt_len = len(target_stmt)

#     for _ in range(start_idx, contents_len):
#         imp_start_idx = contents.find(target_stmt, start_idx)
#         if imp_start_idx < 0:
#             return False

#         # Include the previous char; looking for word boundary
#         if imp_start_idx > 0:
#             imp_start_idx -= 1

#         # Include the next char; looking for word boundary
#         start_idx = imp_start_idx + target_stmt_len
#         imp_end_idx = start_idx + 1
#         if imp_end_idx > contents_len:
#             # We are at the end of the contents
#             imp_end_idx -= 1
#         fragment = contents[imp_start_idx:imp_end_idx]
#         if fragment.strip() == target_stmt:
#             return True

#     return False

def _imports_xctest(repository_ctx, pkg_ctx, target):
    """Determines whether any of the Swift sources for a target import XCTest.

    Args:
        repository_ctx: A `repository_ctx` instance.
        pkg_ctx: A `struct` as created by `pkg_ctxs.new`.
        target: A `struct` as created by `pkginfos.new_target`.

    Returns:
        A `bool` indicating whether the target imports `XCTest`.
    """
    target_path = paths.join(pkg_ctx.pkg_info.path, target.path)
    for src in target.sources:
        path = paths.join(target_path, src)
        file_contents = repository_ctx.read(path)
        if _has_import(file_contents, "XCTest"):
            return True
    return False

swift_files = struct(
    has_import = _has_import,
    has_objc_directive = _has_objc_directive,
    imports_xctest = _imports_xctest,
)
