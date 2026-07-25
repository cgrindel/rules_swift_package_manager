"""Tests for `mach_o` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:link_types.bzl", "link_types")
load("//swiftpkg/internal:mach_o.bzl", "mach_o")
load("//swiftpkg/tests/fixtures/mach_o:fixtures.bzl", "MACH_O_FIXTURES")

# The cputype and cpusubtype fields, which sit between the magic and the
# filetype and are not inspected.
_MACH_O_HEADER_PADDING = ["00"] * 8

def _new_recorded_reader(fixture):
    """Create a reader backed by the bytes recorded for a fixture."""

    def read_bytes(offset, count):
        key = "{offset}:{count}".format(count = count, offset = offset)
        recorded = fixture.reads.get(key)
        if recorded == None:
            fail("""\
No bytes were recorded for {key} in fixture {name}. Regenerate the recordings \
with swiftpkg/tests/fixtures/mach_o/gen_fixtures.sh.\
""".format(key = key, name = fixture.name))
        return recorded

    return read_bytes

def _new_byte_reader(hex_bytes):
    """Create a reader backed by a synthetic `list` of hexadecimal bytes."""

    def read_bytes(offset, count):
        # Returns up to count bytes, matching repository_files.read_bytes,
        # which stops early when the file ends.
        return hex_bytes[offset:offset + count]

    return read_bytes

def _mach_o_binary(magic, filetype):
    return magic + _MACH_O_HEADER_PADDING + filetype

def _uint_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, 0, mach_o.uint_be(["00", "00", "00", "00"]))
    asserts.equals(env, 6, mach_o.uint_be(["00", "00", "00", "06"]))
    asserts.equals(env, 4096, mach_o.uint_be(["00", "00", "10", "00"]))
    asserts.equals(env, 4096, mach_o.uint_be(
        ["00", "00", "00", "00", "00", "00", "10", "00"],
    ))
    asserts.equals(env, 6, mach_o.uint_le(["06", "00", "00", "00"]))
    asserts.equals(env, 4096, mach_o.uint_le(["00", "10", "00", "00"]))

    return unittest.end(env)

uint_test = unittest.make(_uint_test)

def _link_type_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "ar archive",
            hex_bytes = ["21", "3c", "61", "72", "63", "68", "3e", "0a"],
            exp = link_types.static,
        ),
        struct(
            msg = "64-bit little endian dylib",
            hex_bytes = _mach_o_binary(
                ["cf", "fa", "ed", "fe"],
                ["06", "00", "00", "00"],
            ),
            exp = link_types.dynamic,
        ),
        struct(
            msg = "32-bit little endian dylib",
            hex_bytes = _mach_o_binary(
                ["ce", "fa", "ed", "fe"],
                ["06", "00", "00", "00"],
            ),
            exp = link_types.dynamic,
        ),
        struct(
            msg = "64-bit big endian dylib",
            hex_bytes = _mach_o_binary(
                ["fe", "ed", "fa", "cf"],
                ["00", "00", "00", "06"],
            ),
            exp = link_types.dynamic,
        ),
        struct(
            msg = "32-bit big endian dylib",
            hex_bytes = _mach_o_binary(
                ["fe", "ed", "fa", "ce"],
                ["00", "00", "00", "06"],
            ),
            exp = link_types.dynamic,
        ),
        struct(
            # A shared library stub carries the same LC_ID_DYLIB that a dylib
            # does, so it must be treated as dynamically linked. `file` reports
            # it as a "dynamically linked shared library stub".
            msg = "shared library stub is dynamically linked",
            hex_bytes = _mach_o_binary(
                ["cf", "fa", "ed", "fe"],
                ["09", "00", "00", "00"],
            ),
            exp = link_types.dynamic,
        ),
        struct(
            msg = "object file is statically linked",
            hex_bytes = _mach_o_binary(
                ["cf", "fa", "ed", "fe"],
                ["01", "00", "00", "00"],
            ),
            exp = link_types.static,
        ),
        struct(
            msg = "executable is statically linked",
            hex_bytes = _mach_o_binary(
                ["cf", "fa", "ed", "fe"],
                ["02", "00", "00", "00"],
            ),
            exp = link_types.static,
        ),
        struct(
            msg = "bundle is statically linked",
            hex_bytes = _mach_o_binary(
                ["cf", "fa", "ed", "fe"],
                ["08", "00", "00", "00"],
            ),
            exp = link_types.static,
        ),
        struct(
            msg = "big endian object file is statically linked",
            hex_bytes = _mach_o_binary(
                ["fe", "ed", "fa", "cf"],
                ["00", "00", "00", "01"],
            ),
            exp = link_types.static,
        ),
        struct(
            msg = "universal binary wrapping a dylib",
            # magic + nfat_arch + cputype + cpusubtype + offset (32) + size +
            # align, padded out to the slice at offset 32.
            hex_bytes = (
                ["ca", "fe", "ba", "be"] +
                ["00", "00", "00", "01"] +
                _MACH_O_HEADER_PADDING +
                ["00", "00", "00", "20"] +
                ["00"] * 12 +
                _mach_o_binary(
                    ["cf", "fa", "ed", "fe"],
                    ["06", "00", "00", "00"],
                )
            ),
            exp = link_types.dynamic,
        ),
        struct(
            msg = "universal binary wrapping an ar archive",
            hex_bytes = (
                ["ca", "fe", "ba", "be"] +
                ["00", "00", "00", "01"] +
                _MACH_O_HEADER_PADDING +
                ["00", "00", "00", "20"] +
                ["00"] * 12 +
                ["21", "3c", "61", "72", "63", "68", "3e", "0a"]
            ),
            exp = link_types.static,
        ),
        struct(
            msg = "64-bit universal binary wrapping a dylib",
            # The 64-bit fat header stores an eight byte slice offset.
            hex_bytes = (
                ["ca", "fe", "ba", "bf"] +
                ["00", "00", "00", "01"] +
                _MACH_O_HEADER_PADDING +
                ["00", "00", "00", "00", "00", "00", "00", "20"] +
                ["00"] * 8 +
                _mach_o_binary(
                    ["cf", "fa", "ed", "fe"],
                    ["06", "00", "00", "00"],
                )
            ),
            exp = link_types.dynamic,
        ),
    ]
    for t in tests:
        actual = mach_o.link_type(_new_byte_reader(t.hex_bytes))
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

link_type_test = unittest.make(_link_type_test)

def _fixtures_link_type_test(ctx):
    env = unittest.begin(ctx)

    # Exercise the same logic against bytes recorded from real Mach-O binaries.
    # `verify_fixtures.sh` keeps these recordings in sync with the fixtures.
    asserts.true(
        env,
        len(MACH_O_FIXTURES) > 0,
        "Expected at least one recorded Mach-O fixture.",
    )
    for fixture in MACH_O_FIXTURES:
        actual = mach_o.link_type(_new_recorded_reader(fixture))
        asserts.equals(env, fixture.exp_link_type, actual, fixture.name)

    return unittest.end(env)

fixtures_link_type_test = unittest.make(_fixtures_link_type_test)

def mach_o_test_suite(name = "mach_o_tests"):
    return unittest.suite(
        name,
        fixtures_link_type_test,
        link_type_test,
        uint_test,
    )
