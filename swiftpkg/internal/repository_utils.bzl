"""Defintion for repository utility functions."""

def _is_windows(repository_ctx):
    """Determines if the host is running Windows.

    Args:
        repository_ctx: A `repository_ctx` instance.

    Returns:
        A `bool` indicating whether the host is running Windows.
    """
    return repository_ctx.os.name.lower().startswith("windows")

def _package_name(repository_ctx):
    """The name used to declare the Bazel repository.

    This name can be different from the `repository_ctx.name` when using
    bzlmod. Sibling package repositories are found by this name.

    Args:
        repository_ctx: An instance of `repository_ctx`.

    Returns:
        The original repository name unmolested by bzlmod stuff.
    """
    if repository_ctx.attr.bazel_package_name != "":
        return repository_ctx.attr.bazel_package_name
    return repository_ctx.name

def _copy(repository_ctx, src, dest):
    """Copies a file into the repository.

    Reads the content of `src` and writes it to `dest` within the
    repository.  This is useful for copying files without requiring
    the source to use `exports_files(...)`.

    Args:
        repository_ctx: A `repository_ctx` instance.
        src: A `Label` or path pointing to the source file.
        dest: A `string` path for the destination within the repository.
    """
    content = repository_ctx.read(src)
    repository_ctx.file(dest, content = content, executable = False)

def _relativize_repo_path(path, workspace_root):
    """Relativize an absolute path against the Bazel workspace root.

    Local Swift package paths reported by SPM are absolute, which bakes a
    machine-specific path into the lock file when stored as a repository rule
    attribute. When the path is inside the workspace root, this returns the
    workspace-root-relative form so the stored value is portable across
    machines and checkouts. Paths outside the workspace root (e.g. an absolute
    `.package(path:)` or a sibling reached via `../`) cannot be made portable
    and are returned unchanged.

    A trailing slash is appended to the workspace root before matching so that
    a workspace root like "/path/to/MyApp" does not incorrectly match
    "/path/to/MyAppFrameworks".

    Args:
        path: An absolute filesystem path as a `string`.
        workspace_root: The absolute Bazel workspace root as a `string`.

    Returns:
        A `string` that is either the workspace-root-relative path (when
        `path` is inside `workspace_root`) or the original `path` unchanged.
    """
    if not workspace_root:
        return path
    if path == workspace_root:
        return "."
    prefix = workspace_root if workspace_root.endswith("/") else workspace_root + "/"
    if path.startswith(prefix):
        return path[len(prefix):]
    return path

repository_utils = struct(
    copy = _copy,
    is_windows = _is_windows,
    package_name = _package_name,
    relativize_repo_path = _relativize_repo_path,
)
