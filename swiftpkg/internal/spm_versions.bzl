"""Definition for spm_versions module."""

load(":repository_utils.bzl", "repository_utils")

def _extract_version(version):
    """From a raw version string, extract the semantic version number.

    Input: `Swift Package Manager - Swift 5.4.0`
    Output: `5.4.0`

    Args:
        version: A `string` which has the semantic version embedded at the end.

    Returns:
        A `string` representing the semantic version, if found. Otherwise, `None`.
    """

    # Need to parse the version number from `Swift Package Manager - Swift 5.4.0`
    for i in range(len(version)):
        c = version[i]
        if c.isdigit():
            return version[i:].strip()
    return None

def _get_version(repository_ctx, env = {}):
    """Returns the semantic version for Swit Package Manager.

    This is equivalent to running `swift package --version` and returning
    the semantic version.

    Args:
        repository_ctx: A `repository_ctx` instance.
        env: A `dict` of environment variables that are used in the evaluation
             of the SPM version.

    Returns:
        A `string` representing the semantic version for Swift Package Manager.
    """
    exec_out = repository_utils.exec_spm_command(
        repository_ctx,
        ["swift", "package", "--version"],
        env = env,
    )
    return _extract_version(exec_out)

spm_versions = struct(
    extract = _extract_version,
    get = _get_version,
)
