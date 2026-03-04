"""Module for detecting minimum OS versions from the current Xcode SDK."""

# TODO: This entire file is a utility to workaround and resolve:
# https://github.com/cgrindel/rules_swift_package_manager/issues/892
#
# As it stands, theres no way to set `minimum_os_version` in `rules_swift` currently, nor is there
# way to get the minimum OS version from the SDK yet.
# Once that is resolved, this file can be removed and the `minimum_os_version` attribute can be used directly in `rules_swift`.

load(":repository_utils.bzl", "repository_utils")

_SDK_NAMES = {
    "ios": "iphoneos",
    "macos": "macosx",
    "tvos": "appletvos",
    "visionos": "xros",
    "watchos": "watchos",
}

def _get_sdk_path(repository_ctx, sdk_name):
    """Gets the SDK path for a given SDK name using xcrun.

    Args:
        repository_ctx: A `repository_ctx` instance.
        sdk_name: The SDK name (e.g., "iphoneos", "macosx").

    Returns:
        The SDK path as a string, or None if not found.
    """
    result = repository_ctx.execute(
        ["xcrun", "--sdk", sdk_name, "--show-sdk-path"],
        quiet = True,
    )

    if result.return_code != 0:
        fail("Unable to get SDK path for {sdk_name}\n{stdout}\n{stderr}".format(
            sdk_name = sdk_name,
            stdout = result.stdout,
            stderr = result.stderr,
        ))

    return result.stdout.strip()

def _read_min_deployment_target(repository_ctx, sdk_name, sdk_path):
    """Reads the minimum deployment target from the SDK's SDKSettings.plist.

    Args:
        repository_ctx: A `repository_ctx` instance.
        sdk_name: The name of the SDK (e.g., "iphoneos", "macosx").
        sdk_path: The path to the SDK.

    Returns:
        The minimum deployment target version as a string, or None if not found.
    """
    result = repository_ctx.execute(
        [
            "/usr/libexec/PlistBuddy",
            "-c",
            "Print :SupportedTargets:{sdk_name}:MinimumDeploymentTarget".format(
                sdk_name = sdk_name,
            ),
            sdk_path + "/SDKSettings.plist",
        ],
        quiet = True,
    )

    if result.return_code != 0:
        fail("Unable to read minimum deployment target from {sdk_path} for {sdk_name}\n{stdout}\n{stderr}".format(
            sdk_path = sdk_path,
            sdk_name = sdk_name,
            stdout = result.stdout,
            stderr = result.stderr,
        ))

    return result.stdout.strip()

def _get_all(repository_ctx):
    """Gets the minimum OS versions for all Apple platforms from the current Xcode SDK.

    This function only works on macOS where xcrun is available. On other
    platforms (e.g., Linux), it returns an empty dict.

    Args:
        repository_ctx: A `repository_ctx` instance.

    Returns:
        A dict mapping platform names to their minimum OS versions.
        For example: {"ios": "12.0", "macos": "10.13", ...}
    """
    if not repository_utils.is_macos(repository_ctx):
        return {}

    min_versions = {}
    for platform_name, sdk_name in _SDK_NAMES.items():
        sdk_path = _get_sdk_path(repository_ctx, sdk_name)
        if sdk_path:
            min_version = _read_min_deployment_target(repository_ctx, sdk_name, sdk_path)
            if min_version:
                min_versions[platform_name] = min_version

    return min_versions

sdk_min_os_versions = struct(
    get_all = _get_all,
)
