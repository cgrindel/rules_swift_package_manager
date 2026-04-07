"""Constants for SwiftPM manifest compiler flags."""

_BAZEL_DEFINE = [
    "-Xbuild-tools-swiftc",
    "-DBAZEL",
]

manifest_swiftc_args = struct(
    BAZEL_DEFINE = _BAZEL_DEFINE,
)
