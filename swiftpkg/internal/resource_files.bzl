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
_ALL_EXTS = _XIB_EXTS + _ASSET_CATALOG_EXTS + _STRING_CATALOG_EXTS + \
            _COREDATA_EXTS + _METAL_EXTS
_ALL_EXTS_SET = sets.make(_ALL_EXTS)

def _is_resource(path):
    _root, ext_with_dot = paths.split_extension(path)
    if ext_with_dot == "":
        return False
    ext = ext_with_dot[1:]
    return sets.contains(_ALL_EXTS_SET, ext)

resource_files = struct(
    is_resource = _is_resource,
)
