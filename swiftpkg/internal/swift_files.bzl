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
        if file_contents.find("import XCTest") > -1:
            return True
    return False

swift_files = struct(
    has_objc_directive = _has_objc_directive,
    imports_xctest = _imports_xctest,
)
