"""API for creating and loading Swift package information."""

load(":repository_utils.bzl", "repository_utils")

def _new(directory, dump_manifest, desc_manifest):
    return struct(
        directory = directory,
        dump_manifest = dump_manifest,
        desc_manifest = desc_manifest,
    )

def _get_dump_manifest(repository_ctx, env = {}, working_directory = ""):
    """Returns a dict representing the package dump for an SPM package.

    Args:
        repository_ctx: A `repository_ctx`.
        env: A `dict` of environment variables that will be included in the
             command execution.
        working_directory: A `string` specifying the directory for the SPM package.

    Returns:
        A `dict` representing an SPM package dump.
    """
    json_str = repository_utils.exec_spm_command(
        repository_ctx,
        ["swift", "package", "dump-package"],
        env = env,
        working_directory = working_directory,
    )
    return json.decode(json_str)

def _get_desc_manifest(repository_ctx, env = {}, working_directory = ""):
    """Returns a dict representing the package description for an SPM package.

    Args:
        repository_ctx: A `repository_ctx`.
        env: A `dict` of environment variables that will be included in the
             command execution.
        working_directory: A `string` specifying the directory for the SPM package.

    Returns:
        A `dict` representing an SPM package description.
    """
    json_str = repository_utils.exec_spm_command(
        repository_ctx,
        ["swift", "package", "describe", "--type", "json"],
        env = env,
        working_directory = working_directory,
    )
    return json.decode(json_str)

def _get(repository_ctx, directory, env = {}):
    dump_manifest = _get_dump_manifest(
        repository_ctx,
        env = env,
        working_directory = directory,
    )
    desc_manifest = _get_desc_manifest(
        repository_ctx,
        env = env,
        working_directory = directory,
    )
    return _new(directory, dump_manifest, desc_manifest)

package_infos = struct(
    new = _new,
    get = _get,
)
