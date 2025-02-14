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

def _find_license_files(repository_ctx):
    """Retrieves all license files at the root of the package.

    Args:
        repository_ctx: A `repository_ctx` instance.

    Returns:
        A `list` of path `string` values.
    """

    find_args = [
        "find",
        # Follow symlinks and report on the actual files.
        "-H",
        "-L",
        ".",
        # For GNU find, it is important for the global options (e.g. -maxdepth)
        # to be specified BEFORE other options like -type. Also, GNU find does
        # not support -depth <level>. So, we approximate it by using -mindepth
        # and -maxdepth.
        "-mindepth",
        "1",
        "-maxdepth",
        "1",
        "-type",
        "f",
        "(",
        "-name",
        "LICENSE",
        "-o",
        "-name",
        "LICENSE.*",
        ")",
    ]

    exec_result = repository_ctx.execute(find_args, quiet = True)
    if exec_result.return_code != 0:
        fail("Failed to find license files. stderr:\n%s" % exec_result.stderr)
    return _process_find_results(
        exec_result.stdout,
        find_path = ".",
    )

def _list_files_under(
        repository_ctx,
        path,
        exclude_paths = [],
        exclude_directories = False,
        by_name = None,
        depth = None):
    """Retrieves the list of files under the specified path.

    This function returns paths for all of the files under the specified path.

    Args:
        repository_ctx: A `repository_ctx` instance.
        path: A path `string` value.
        exclude_paths: Optional. A `list` of path `string` values that should be
            excluded from the result.
        exclude_directories: Optional. Exclude directories from the result.
        by_name: Optional. The name pattern that must be matched.
        depth: Optional. The depth as an `int` at which the directory must
            live from the starting path.

    Returns:
        A `list` of path `string` values.
    """

    # Follow symlinks and report on the actual files.
    find_args = ["find", "-H", "-L", path]

    # For GNU find, it is important for the global options (e.g. -maxdepth) to be
    # specified BEFORE other options like -type. Also, GNU find does not support -depth <level>.
    # So, we approximate it by using -mindepth and -maxdepth.
    if depth != None:
        depth_str = "{}".format(depth)
        find_args.extend(["-mindepth", depth_str, "-maxdepth", depth_str])
    if by_name != None:
        find_args.extend(["-name", by_name])
    if exclude_directories:
        find_args.extend(["-not", "-type", "d"])
    exec_result = repository_ctx.execute(find_args, quiet = True)
    if exec_result.return_code != 0:
        fail("Failed to list files in %s. stderr:\n%s" % (path, exec_result.stderr))
    return _process_find_results(
        exec_result.stdout,
        find_path = path,
        exclude_paths = exclude_paths,
        remove_find_path = False,
    )

def _list_directories_under(
        repository_ctx,
        path,
        max_depth = None,
        by_name = None,
        depth = None,
        exclude_paths = []):
    """Retrieves the list of directories under the specified path.

    Args:
        repository_ctx: A `repository_ctx` instance.
        path: A path `string` value.
        max_depth: Optional. The maximum depth for the directory search.
        by_name: Optional. The name pattern that must be matched.
        depth: Optional. The depth as an `int` at which the directory must
            live from the starting path.
        exclude_paths: Optional. A `list` of path `string` values that should be
            excluded from the result.

    Returns:
        A `list` of path `string` values.
    """

    # Follow symlinks and report on the actual directories.
    find_args = ["find", "-H", "-L", path]

    # For GNU find, it is important for the global options (e.g. -maxdepth) to be
    # specified BEFORE other options like -type. Also, GNU find does not support -depth <level>.
    # So, we approximate it by using -mindepth and -maxdepth.
    if depth != None:
        depth_str = "{}".format(depth)
        find_args.extend(["-mindepth", depth_str])
        if max_depth == None:
            find_args.extend(["-maxdepth", depth_str])
    if max_depth != None:
        find_args.extend(["-maxdepth", "%d" % (max_depth)])
    find_args.extend(["-type", "d"])
    if by_name != None:
        find_args.extend(["-name", by_name])

    exec_result = repository_ctx.execute(find_args, quiet = True)
    if exec_result.return_code != 0:
        fail("Failed to list directories under %s. stderr:\n%s" % (path, exec_result.stderr))
    return _process_find_results(
        exec_result.stdout,
        find_path = path,
        exclude_paths = exclude_paths,
        remove_find_path = True,
    )

def _process_find_results(raw_output, find_path, exclude_paths = [], remove_find_path = False):
    path_list = raw_output.splitlines()

    # Do not include the find path
    if remove_find_path:
        path_list = [p for p in path_list if p != find_path]

    # The starting path will be prefixed to the results. If the starting path is dot (.),
    # the prefix for the results will be `./`. We will remove it before returning the results.
    path_list = [p.removeprefix("./") for p in path_list]
    return _exclude_paths(path_list, exclude_paths)

def _exclude_paths(path_list, exclude_paths):
    """Filter the list of paths using the provided exclude list.

    Args:
        path_list: A `list` of paths as `string` values.
        exclude_paths: A `list` of paths to files or directories to exclude from
            the provided paths.

    Returns:
        The input `list` with the files and directories excluded.
    """
    if len(exclude_paths) == 0:
        return path_list

    # The exclude path could be a directory.
    excludes_as_dirs = lists.map(
        exclude_paths,
        lambda ex: ex if ex.endswith("/") else ex + "/",
    )

    # If someone added a slash at the end, then it is a directory
    excludes_as_files = lists.filter(
        exclude_paths,
        lambda ex: not ex.endswith("/"),
    )

    results = []
    for path in path_list:
        if lists.contains(excludes_as_files, path):
            continue
        match = lists.find(excludes_as_dirs, lambda ex: path.startswith(ex))
        if match != None:
            continue
        results.append(path)

    return results

def _find_and_delete_files(repository_ctx, path, name, exclude_paths = []):
    """Finds files with the specified name under the specified path and deletes them.

    Args:
        repository_ctx: A `repository_ctx` instance.
        path: A path `string` value.
        name: A file basename as a `string`.
        exclude_paths: Optional. A `list` of path `string` values to exclude
            from the search.
    """
    find_args = ["find", path, "-type", "f", "-name", name]
    exclude_args = lists.flatten([
        ["-not", "-path", path + "/" + exclude_path]
        for exclude_path in exclude_paths
    ])
    rm_args = ["-delete"]
    all_args = find_args + exclude_args + rm_args
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
    exec_result = repository_ctx.execute(
        ["test", "-d", path],
        quiet = True,
    )
    return exec_result.return_code == 0

def _file_type(repository_ctx, path):
    """Output the file type.

    Args:
        repository_ctx: An instance of `repository_ctx`.
        path: The path to test as a `string`.

    Returns:
        A `string` representing the file type for the path as returned by the
        `file` utility.
    """
    file_args = ["file", "--brief", path]
    exec_result = repository_ctx.execute(file_args, quiet = True)
    if exec_result.return_code != 0:
        fail("Failed to determine the file type for {path}. stderr:\n{stderr}".format(
            path = path,
            stderr = exec_result.stderr,
        ))
    return exec_result.stdout.removesuffix("\n")

repository_files = struct(
    copy_directory = _copy_directory,
    exclude_paths = _exclude_paths,
    file_type = _file_type,
    find_and_delete_files = _find_and_delete_files,
    find_license_files = _find_license_files,
    is_directory = _is_directory,
    list_directories_under = _list_directories_under,
    list_files_under = _list_files_under,
    path_exists = _path_exists,
    # Exposed for testing purposes only.
    process_find_results = _process_find_results,
)
