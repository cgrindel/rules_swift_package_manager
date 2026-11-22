"""Apple SDKs supported by the SDK inventory."""

load(
    "//config_settings/bazel/apple_platform_type:apple_platform_types.bzl",
    "apple_platform_types",
)

_DEVICE = "device"
_SIMULATOR = "simulator"

def _new(platform, triple_os, environment):
    """Create an SDK description.

    Args:
        platform: The Bazel Apple platform type as a `string`.
        triple_os: The OS component of the SDK's target triple, without the
            deployment version, as a `string` (e.g. `ios`, `macosx`).
        environment: `device` or `simulator`.

    Returns:
        A `struct` describing the SDK.
    """
    return struct(
        platform = platform,
        triple_os = triple_os,
        environment = environment,
        # The environment component of the target triple. Device triples have
        # none, e.g. `arm64-apple-ios17.0` vs `arm64-apple-ios17.0-simulator`.
        triple_environment = "" if environment == _DEVICE else environment,
    )

_SDKS = {
    "AppleTVOS": _new(apple_platform_types.tvos, "tvos", _DEVICE),
    "AppleTVSimulator": _new(apple_platform_types.tvos, "tvos", _SIMULATOR),
    "MacOSX": _new(apple_platform_types.macos, "macosx", _DEVICE),
    "WatchOS": _new(apple_platform_types.watchos, "watchos", _DEVICE),
    "WatchSimulator": _new(
        apple_platform_types.watchos,
        "watchos",
        _SIMULATOR,
    ),
    "XROS": _new(apple_platform_types.visionos, "xros", _DEVICE),
    "XRSimulator": _new(apple_platform_types.visionos, "xros", _SIMULATOR),
    "iPhoneOS": _new(apple_platform_types.ios, "ios", _DEVICE),
    "iPhoneSimulator": _new(apple_platform_types.ios, "ios", _SIMULATOR),
}

sdks = struct(
    device = _DEVICE,
    get = lambda name: _SDKS.get(name),
    names = sorted(_SDKS),
    simulator = _SIMULATOR,
)
