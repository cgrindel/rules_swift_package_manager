"""Module for retrieving and manipulating repository file information."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")

def _path_exists(repository_ctx, path):
    """Determines if the specified path exists.

    Args:
        repository_ctx: A `repository_ctx` instance.
        path: A path `string` value.

    Returns:
        A `bool` indicating whether the path exists.
    """
    exec_result = repository_ctx.execute(
        ["test", "-e", path],
        quiet = True,
    )
    return exec_result.return_code == 0

def _list_files_under(repository_ctx, path, exclude = []):
    """Retrieves the list of files under the specified path.

    This function returns paths for all of the files under the specified path.

    Args:
        repository_ctx: A `repository_ctx` instance.
        path: A path `string` value.
        exclude: Optional. A `list` of path `string` values that should be
            excluded from the result.

    Returns:
        A `list` of path `string` values.
    """
    exec_result = repository_ctx.execute(
        # Follow symlinks and report on the actual files.
        ["find", "-H", "-L", path],
        quiet = True,
    )
    if exec_result.return_code != 0:
        fail("Failed to list files in %s. stderr:\n%s" % (path, exec_result.stderr))
    path_list = exec_result.stdout.splitlines()
    path_list = _exclude_paths(path_list, exclude)
    return path_list

def _exclude_paths(path_list, exclude):
    """Filter the list of paths using the provided exclude list.

    An exclude list item can be a file or a directory. An entry is considered a
    directory if it has a trailing slash (`/`). If a path equals a file entry,
    it is excluded. If a path starts with a directory entry, it is excluded.

    Args:
        path_list: A `list` of paths as `string` values.
        exclude: A `list` of files and directories to exclude from the provided
            paths.

    Returns:
        The input `list` with the files and directories excluded.
    """
    exclude_files = []
    exclude_dirs = []
    for ex in exclude:
        if ex.endswith("/"):
            exclude_dirs.append(ex)
        else:
            exclude_files.append(ex)

    results = []
    for path in path_list:
        if lists.contains(exclude_files, path):
            continue
        keep = True
        for exd in exclude_dirs:
            if path.startswith(exd):
                keep = False
                break
        if keep:
            results.append(path)

    return results

def _list_directories_under(repository_ctx, path, max_depth = None):
    """Retrieves the list of directories under the specified path.

    Args:
        repository_ctx: A `repository_ctx` instance.
        path: A path `string` value.
        max_depth: Optional. The depth for the directory search.

    Returns:
        A `list` of path `string` values.
    """
    find_args = ["find", path, "-type", "d"]
    if max_depth != None:
        find_args.extend(["-maxdepth", "%d" % (max_depth)])
    exec_result = repository_ctx.execute(find_args, quiet = True)
    if exec_result.return_code != 0:
        fail("Failed to list directories under %s. stderr:\n%s" % (path, exec_result.stderr))
    paths = exec_result.stdout.splitlines()
    return [p for p in paths if p != path]

def _find_and_delete_files(repository_ctx, path, name):
    """Finds files with the specified name under the specified path and deletes them.

    Args:
        repository_ctx: A `repository_ctx` instance.
        path: A path `string` value.
        name: A file basename as a `string`.
    """
    find_args = ["find", path, "-type", "f", "-name", name]
    rm_args = ["-delete"]
    all_args = find_args + rm_args
    exec_result = repository_ctx.execute(all_args, quiet = True)
    if exec_result.return_code != 0:
        fail("Failed to remove files named {name} under {path}. stderr:\n{stderr}".format(
            name = name,
            path = path,
            stderr = exec_result.stderr,
        ))

def _copy_directory(repository_ctx, src, dest):
    """Copy a directory.

    Args:
        repository_ctx: An instance of `repository_ctx`.
        src: The path to the direcotry to copy as a `string`.
        dest: The path where the directory will be copied as a `string`.
    """

    # Copy the sources from the checkout directory
    repository_ctx.execute(
        [
            "cp",
            "-R",
            "-f",
            src,
            dest,
        ],
    )

def _is_directory(repository_ctx, path):
    """Determine if the provided path is a directory.

    Args:
        repository_ctx: An instance of `repository_ctx`.
        path: The path to test as a `string`.

    Returns:
        A `bool` specifying whether the path is a directory.
    """
    args = ["bash", "-c", "if [[ -d ${TARGET_PATH} ]]; then echo TRUE; else echo FALSE; fi"]
    exec_result = repository_ctx.execute(
        args,
        environment = {"TARGET_PATH": path},
        quiet = True,
    )
    if exec_result.return_code != 0:
        fail("Failed while checking if '{path}' is a directory. stderr:\n{stderr}".format(
            path = path,
            stderr = exec_result.stderr,
        ))
    if exec_result.stdout.find("TRUE") >= 0:
        return True
    return False

repository_files = struct(
    copy_directory = _copy_directory,
    exclude_paths = _exclude_paths,
    find_and_delete_files = _find_and_delete_files,
    is_directory = _is_directory,
    list_directories_under = _list_directories_under,
    list_files_under = _list_files_under,
    path_exists = _path_exists,
)
