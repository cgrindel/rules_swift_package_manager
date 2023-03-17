"""Defintion for repository utility functions."""

load("@bazel_skylib//lib:paths.bzl", "paths")

def _is_macos(repository_ctx):
    """Determines if the host is running MacOS.

    Args:
        repository_ctx: A `repository_ctx` instance.

    Returns:
        A `bool` indicating whether the host is running MacOS.
    """
    os_name = repository_ctx.os.name.lower()
    return os_name.startswith("mac os")

def _execute_spm_command(
        repository_ctx,
        arguments,
        env = {},
        working_directory = "",
        err_msg_tpl = None):
    """Executes a Swift package manager command and returns the stdout.

    If the command returns a non-zero return code, this function will fail.

    Args:
        repository_ctx: A `repository_ctx` instance.
        arguments: A `list` of arguments which will be executed.
        env: A `dict` of environment variables that will be included in the
             command execution.
        working_directory: Working directory for command execution. Can be
                           relative to the repository root or absolute.
        err_msg_tpl: Optional. A `string` template which will be formatted with
                     the `exec_args` and `stderr` values.

    Returns:
        A `string` representing the stdout of the command execution.
    """
    exec_args = []
    if _is_macos(repository_ctx):
        exec_args.append("xcrun")
    exec_args.extend(arguments)
    exec_result = repository_ctx.execute(
        exec_args,
        environment = env,
        working_directory = working_directory,
    )
    if exec_result.return_code != 0:
        if err_msg_tpl == None:
            err_msg_tpl = """\
Failed to execute SPM command. name: {repo_name}, args: {exec_args}\n{stderr}.\
"""
        fail(err_msg_tpl.format(
            repo_name = repository_ctx.attr.name,
            exec_args = exec_args,
            stderr = exec_result.stderr,
        ))
    return exec_result.stdout

def _parsed_json_from_spm_command(
        repository_ctx,
        arguments,
        env = {},
        working_directory = "",
        debug_json_path = None):
    json_str = repository_utils.exec_spm_command(
        repository_ctx,
        arguments,
        env = env,
        working_directory = working_directory,
    )
    if debug_json_path:
        if not paths.is_absolute(debug_json_path):
            debug_json_path = paths.join(working_directory, debug_json_path)
        repository_ctx.file(debug_json_path, content = json_str, executable = False)
    return json.decode(json_str)

def _repo_name(repository_ctx):
    """Extracts the repository name without a parent repository prefix as can \
    be added by bzlmod.

    Args:
        repository_ctx: An instance of `repository_ctx`.

    Returns:
        The repository name without a parent repoitory prefix.
    """
    name = repository_ctx.name
    if name.find("~") < 0:
        return name
    return name.split("~")[-1]

repository_utils = struct(
    exec_spm_command = _execute_spm_command,
    is_macos = _is_macos,
    parsed_json_from_spm_command = _parsed_json_from_spm_command,
    repo_name = _repo_name,
)
