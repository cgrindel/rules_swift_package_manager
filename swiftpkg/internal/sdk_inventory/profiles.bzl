"""Validation and environment for reproducible compiler scan profiles."""

load(":sdks.bzl", "sdks")

def _error(sdk, triple):
    sdk_info = sdks.get(sdk)
    if not sdk_info:
        return "Unsupported scan SDK: " + sdk
    parts = triple.split("-")
    if len(parts) not in [3, 4] or parts[1] != "apple":
        return "Invalid Apple target triple: " + triple
    if parts[0] not in ["arm64", "x86_64"]:
        return "Unsupported SDK scan architecture: " + parts[0]
    version = parts[2].removeprefix(sdk_info.triple_os)
    version_is_numeric = all([p.isdigit() for p in version.split(".")])
    if (not parts[2].startswith(sdk_info.triple_os) or
        not version or
        not version_is_numeric):
        return """\
Target {} does not match SDK {} (expected {} with a deployment version)\
""".format(triple, sdk, sdk_info.triple_os)
    triple_environment = parts[3] if len(parts) == 4 else ""
    if triple_environment != sdk_info.triple_environment:
        return "Target {} does not match SDK {} environment".format(triple, sdk)
    if (sdk_info.environment == sdks.device and
        sdk != "MacOSX" and
        parts[0] != "arm64"):
        return "Device SDK {} requires an arm64 scan target".format(sdk)
    return None

def _environment(developer_dir):
    # Host include paths must not change canImport without becoming scan inputs.
    # These profiles intentionally support only the selected default toolchain.
    return {
        "CLANG_MODULE_CACHE_PATH": "",
        "CPATH": "",
        "CPLUS_INCLUDE_PATH": "",
        "C_INCLUDE_PATH": "",
        "DEVELOPER_DIR": developer_dir,
        "OBJC_INCLUDE_PATH": "",
        "SDKROOT": "",
        "SWIFT_MODULECACHE_PATH": "",
        "TOOLCHAINS": "com.apple.dt.toolchain.XcodeDefault",
    }

sdk_scan_profiles = struct(error = _error, environment = _environment)
