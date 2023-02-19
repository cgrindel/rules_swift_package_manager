"""Module for Swift file operations."""

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

swift_files = struct(
    has_objc_directive = _has_objc_directive,
)
