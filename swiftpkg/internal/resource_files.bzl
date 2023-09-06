"""Module for evaluating resource files."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:sets.bzl", "sets")

# For a list of the auto-discovered resource types, see
# https://github.com/apple/swift-package-manager/blob/main/Sources/PackageLoading/TargetSourcesBuilder.swift#L634-L677
_XIB_EXTS = ["nib", "xib", "storyboard"]
_ASSET_CATALOG_EXTS = ["xcassets"]
_STRING_CATALOG_EXTS = ["xcstrings"]
_COREDATA_EXTS = ["xcdatamodeld", "xcdatamodel", "xcmappingmodel"]
_METAL_EXTS = ["metal"]
_ALL_AUTO_DISCOVERED_RES_EXTS = _XIB_EXTS + _ASSET_CATALOG_EXTS + \
                                _STRING_CATALOG_EXTS + _COREDATA_EXTS + _METAL_EXTS
_ALL_AUTO_DISCOVERED_RES_EXTS_SET = sets.make(_ALL_AUTO_DISCOVERED_RES_EXTS)

def _is_under_asset_catalog_dir(path):
    for ext in _ASSET_CATALOG_EXTS:
        # This won't work for Windows. It is unclear how to determine to proper
        # separator to use. The bazel-skylib paths.bzl just uses forward slash
        # (/) without checking.
        pattern = ".{}/".format(ext)
        if path.find(pattern) > 0:
            return True
    return False

def _is_auto_discovered_resource(path):
    """Determines whether the specified path points to an auto-discoverable \
    resource.

    [SPM automatically detects certain resource
    types.](https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageDescription.md#resource)
    This function determines if the specified path points to one of these
    special resoure files.

    Args:
        path: A `string` representing a path to a file.

    Returns:
        A `bool` representing whether the path is an auto-discoverable resource.
    """
    _root, ext_with_dot = paths.split_extension(path)
    ext = ext_with_dot[1:] if ext_with_dot != "" else ""
    return sets.contains(_ALL_AUTO_DISCOVERED_RES_EXTS_SET, ext) or \
           _is_under_asset_catalog_dir(path) or \
           False

resource_files = struct(
    is_auto_discovered_resource = _is_auto_discovered_resource,
)
