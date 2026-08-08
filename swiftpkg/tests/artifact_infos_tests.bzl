"""Tests for `artifact_infos` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:artifact_infos.bzl", "artifact_infos", "link_types")
load(":testutils.bzl", "testutils")

_DYLIB_BINARY = testutils.new_mach_o_binary(
    ["cf", "fa", "ed", "fe"],
    ["06", "00", "00", "00"],
)

_ARCHIVE_BINARY = ["21", "3c", "61", "72", "63", "68", "3e", "0a"]

def _link_type_test(ctx):
    env = unittest.begin(ctx)

    # These exercise artifact_infos.link_type end to end, through the byte
    # reads that repository_files.read_bytes performs. The exhaustive coverage
    # of the header formats lives in mach_o_tests.bzl.
    tests = [
        struct(
            msg = "ar archive",
            binary = _ARCHIVE_BINARY,
            exp = link_types.static,
        ),
        struct(
            msg = "mach-o dynamic library",
            binary = _DYLIB_BINARY,
            exp = link_types.dynamic,
        ),
        struct(
            msg = "mach-o object file",
            binary = testutils.new_mach_o_binary(
                ["cf", "fa", "ed", "fe"],
                ["01", "00", "00", "00"],
            ),
            exp = link_types.static,
        ),
        struct(
            msg = "universal binary wrapping a dynamic library",
            # fat magic + nfat_arch + the slice's cputype and cpusubtype +
            # the slice offset, padded out to the slice at offset 32.
            binary = (
                ["ca", "fe", "ba", "be"] +
                ["00", "00", "00", "01"] +
                ["00"] * 8 +
                ["00", "00", "00", "20"] +
                ["00"] * 12 +
                _DYLIB_BINARY
            ),
            exp = link_types.dynamic,
        ),
    ]
    for t in tests:
        path = "path/to/framework/binary/FooBar"
        stub_repository_ctx = testutils.new_stub_repository_ctx(
            repo_name = "chicken",
            binary_contents = {path: t.binary},
        )
        actual = artifact_infos.link_type(stub_repository_ctx, path)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

link_type_test = unittest.make(_link_type_test)

def _versioned_macos_framework_test(ctx):
    env = unittest.begin(ctx)
    xcframework_path = "Breez.xcframework"
    framework_path = xcframework_path + "/macos-arm64_x86_64/Breez.framework"
    binary_path = framework_path + "/Versions/Current/Breez"
    repository_ctx = testutils.new_stub_repository_ctx(
        repo_name = "breez",
        find_results = {
            xcframework_path: [framework_path],
            framework_path: [],
        },
        path_exists_results = {binary_path: True},
        binary_contents = {binary_path: _DYLIB_BINARY},
    )

    actual = artifact_infos.new_xcframework_info_from_files(repository_ctx, xcframework_path)

    asserts.equals(env, link_types.dynamic, actual.link_type)
    return unittest.end(env)

versioned_macos_framework_test = unittest.make(_versioned_macos_framework_test)

def artifact_infos_test_suite(name = "artifact_infos_tests"):
    return unittest.suite(
        name,
        link_type_test,
        versioned_macos_framework_test,
    )
