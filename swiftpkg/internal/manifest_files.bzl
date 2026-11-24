"""Readers for manifest files that the cache tool writes.

These need a real `module_ctx` or `repository_ctx`, so they are not unit
tested here. The integration tests cover them.
"""

def _read_text(ctx, label_or_path):
    """Returns the contents of a file, or `None` if it does not exist.

    Args:
        ctx: A `module_ctx` or `repository_ctx`.
        label_or_path: A `Label`, a `string` path, or a `path`.

    Returns:
        The file contents as a `string`, or `None`.
    """
    path = ctx.path(label_or_path)
    if not path.exists:
        return None
    return ctx.read(path)

def _read_json(ctx, label):
    """Returns the decoded JSON from a file, or `None` if it does not exist.

    Args:
        ctx: A `module_ctx` or `repository_ctx`.
        label: A `Label`, a `string` path, or a `path`.

    Returns:
        The decoded JSON value, or `None`.
    """
    text = _read_text(ctx, label)
    if text == None:
        return None
    return json.decode(text)

manifest_files = struct(
    read_json = _read_json,
    read_text = _read_text,
)
