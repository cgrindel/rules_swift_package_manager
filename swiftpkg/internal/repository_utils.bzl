"""Defintion for repository utility functions."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
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

    # It is critical that the SPM commands execute using the host's default
    # SDK. This is typically MacOS.  If the SDKROOT is set to iOS for example,
    # the SPM command will fail because it cannot compile the package manifest.
    # Example: rules_xcodeproj sets the SDKROOT before executing
    # generate_bazel_dependencies.sh.
    env_overrides = {"SDKROOT": ""}
    exec_env = dicts.add(env, env_overrides)

    exec_result = repository_ctx.execute(
        exec_args,
        environment = exec_env,
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

def _package_name(repository_ctx):
    """The name used to declare the Bazel repository.

    This name can be different from the `repository_ctx.name` when using
    bzlmod. This value is used for lookups in the Swift deps index.

    Args:
        repository_ctx: An instance of `repository_ctx`.

    Returns:
        The original repository name unmolested by bzlmod stuff.
    """
    if repository_ctx.attr.bazel_package_name != "":
        return repository_ctx.attr.bazel_package_name
    return repository_ctx.name

repository_utils = struct(
    exec_spm_command = _execute_spm_command,
    is_macos = _is_macos,
    package_name = _package_name,
    parsed_json_from_spm_command = _parsed_json_from_spm_command,
)
