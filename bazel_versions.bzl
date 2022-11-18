"""Specifies the supported Bazel versions"""

CURRENT_BAZEL_VERSION = "//:.bazelversion"

SUPPORTED_BAZEL_VERSIONS = [
    CURRENT_BAZEL_VERSION,
    "6.0.0rc1",
    "7.0.0-pre.20221102.3",
]
