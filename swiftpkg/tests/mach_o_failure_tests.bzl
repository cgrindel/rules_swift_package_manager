"""Failure tests for the `mach_o` and `repository_files` byte readers.

The guards in these modules all report problems with `fail()`, which the
`unittest` framework cannot observe: the first one aborts the whole test. These
tests drive the same code from a rule implementation instead, where
`analysistest` can assert that analysis failed and check the message.

Without these, every bounds check is dead weight. Removing one leaves the
positive tests passing, and a truncated binary silently resolves to `static`
rather than reporting the truncation.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//swiftpkg/internal:mach_o.bzl", "mach_o")
load("//swiftpkg/internal:repository_files.bzl", "repository_files")

# MARK: - Rules under test

def _link_type_impl(ctx):
    hex_bytes = ctx.attr.hex_bytes

    def read_bytes(offset, count):
        # Returns up to count bytes, matching repository_files.read_bytes.
        return hex_bytes[offset:offset + count]

    mach_o.link_type(read_bytes)
    return []

_link_type_target = rule(
    implementation = _link_type_impl,
    attrs = {
        "hex_bytes": attr.string_list(
            doc = "The synthetic binary, as hexadecimal byte values.",
        ),
    },
)

def _parse_od_output_impl(ctx):
    repository_files.parse_od_output(
        ctx.attr.stdout,
        ctx.attr.count,
        "path/to/binary",
        0,
    )
    return []

_parse_od_output_target = rule(
    implementation = _parse_od_output_impl,
    attrs = {
        "count": attr.int(doc = "The maximum number of bytes requested."),
        "stdout": attr.string(doc = "The stdout to parse."),
    },
)

# MARK: - Test implementation

def _expect_failure_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.exp_message)
    return analysistest.end(env)

_expect_failure_test = analysistest.make(
    _expect_failure_impl,
    expect_failure = True,
    attrs = {
        "exp_message": attr.string(
            doc = "A fragment of the expected failure message.",
        ),
    },
)

# MARK: - Cases

_MACH_O_LE_MAGIC = ["cf", "fa", "ed", "fe"]
_FAT_MAGIC = ["ca", "fe", "ba", "be"]
_ONE_ARCH = ["00", "00", "00", "01"]

_LINK_TYPE_CASES = [
    struct(
        name = "truncated_mach_o_header",
        # The magic is present but the header stops before the filetype at
        # byte 12. Reading it anyway would yield a filetype of zero, which is
        # not MH_DYLIB, so the binary would silently resolve to static.
        hex_bytes = _MACH_O_LE_MAGIC + ["00"] * 10,
        exp_message = "is truncated",
    ),
    struct(
        name = "empty_binary",
        hex_bytes = [],
        exp_message = "is truncated",
    ),
    struct(
        name = "unrecognized_magic",
        hex_bytes = ["de", "ad", "be", "ef"] + ["00"] * 20,
        exp_message = "Unrecognized magic bytes",
    ),
    struct(
        name = "incomplete_ar_magic",
        # Starts like an ar archive but the rest of `!<arch>\n` is wrong.
        hex_bytes = ["21", "3c", "61", "72", "00", "00", "00", "00"] +
                    ["00"] * 16,
        exp_message = "archive magic",
    ),
    struct(
        name = "fat_with_no_architectures",
        hex_bytes = _FAT_MAGIC + ["00", "00", "00", "00"] + ["00"] * 16,
        exp_message = "declares no architectures",
    ),
    struct(
        name = "fat_slice_at_offset_zero",
        # A slice cannot start where the fat header itself lives. Walking
        # there would re-read the fat magic and misreport a nested binary.
        hex_bytes = _FAT_MAGIC + _ONE_ARCH + ["00"] * 8 +
                    ["00", "00", "00", "00"] + ["00"] * 4,
        exp_message = "offset of zero",
    ),
    struct(
        name = "fat_wrapping_fat",
        hex_bytes = _FAT_MAGIC + _ONE_ARCH + ["00"] * 8 +
                    ["00", "00", "00", "18"] + ["00"] * 4 +
                    _FAT_MAGIC + _ONE_ARCH + ["00"] * 8 +
                    ["00", "00", "00", "30"] + ["00"] * 4,
        exp_message = "nested inside a universal binary",
    ),
]

_PARSE_OD_OUTPUT_CASES = [
    struct(
        name = "no_bytes_read",
        # od exits zero with empty output when the offset lands exactly at the
        # end of the file.
        stdout = "\n",
        count = 4,
        exp_message = "Read no bytes",
    ),
    struct(
        name = "more_bytes_than_requested",
        stdout = " cf fa ed fe 0c 00\n",
        count = 4,
        exp_message = "but only 4 were requested",
    ),
]

def mach_o_failure_test_suite(name = "mach_o_failure_tests"):
    """Declares the failure tests and the targets they analyze.

    Args:
        name: The name of the resulting test suite as a `string`.
    """
    test_names = []

    for case in _LINK_TYPE_CASES:
        target_name = "{}_subject".format(case.name)
        test_name = "{}_test".format(case.name)
        _link_type_target(
            name = target_name,
            hex_bytes = case.hex_bytes,
            tags = ["manual"],
        )
        _expect_failure_test(
            name = test_name,
            exp_message = case.exp_message,
            target_under_test = ":" + target_name,
        )
        test_names.append(test_name)

    for case in _PARSE_OD_OUTPUT_CASES:
        target_name = "{}_subject".format(case.name)
        test_name = "{}_test".format(case.name)
        _parse_od_output_target(
            name = target_name,
            count = case.count,
            stdout = case.stdout,
            tags = ["manual"],
        )
        _expect_failure_test(
            name = test_name,
            exp_message = case.exp_message,
            target_under_test = ":" + target_name,
        )
        test_names.append(test_name)

    native.test_suite(
        name = name,
        tests = [":" + tn for tn in test_names],
    )
