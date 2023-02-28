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

def _has_import(contents, target_import):
    """Determines whether a string contains a Swift import statement for module.

    Args:
        contents: A `string` value to be evaluated.
        target_import: The name of the imported module as a `string`.

    Returns:
        A `bool` indicating whether an import statement for the module was found.
    """
    contents_len = len(contents)
    start_idx = 0
    target_stmt = "import {}".format(target_import)
    target_stmt_len = len(target_stmt)

    for _ in range(start_idx, contents_len):
        imp_start_idx = contents.find(target_stmt, start_idx)
        if imp_start_idx < 0:
            return False

        # Include the previous char; looking for word boundary
        if imp_start_idx > 0:
            imp_start_idx -= 1

        # Include the next char; looking for word boundary
        start_idx = imp_start_idx + target_stmt_len
        imp_end_idx = start_idx + 1
        if imp_end_idx > contents_len:
            # We are at the end of the contents
            imp_end_idx -= 1
        fragment = contents[imp_start_idx:imp_end_idx]
        if fragment.strip() == target_stmt:
            return True

    return False

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
