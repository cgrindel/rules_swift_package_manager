"""Tests for `swift_package_tool` helpers."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:swift_package_tool.bzl", "swift_package_tool_testing")

def _manifest_swiftc_flags_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        "-Xbuild-tools-swiftc -DBAZEL",
        swift_package_tool_testing.manifest_swiftc_flags(),
    )

    return unittest.end(env)

manifest_swiftc_flags_test = unittest.make(_manifest_swiftc_flags_test)

def swift_package_tool_test_suite():
    return unittest.suite(
        "swift_package_tool_tests",
        manifest_swiftc_flags_test,
    )
