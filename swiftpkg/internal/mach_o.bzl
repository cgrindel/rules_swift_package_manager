"""Module for determining how a Mach-O binary or `ar` archive is linked.

The link type is derived from the magic bytes at the start of the binary and,
for Mach-O files, the `filetype` field in the Mach-O header. Reading the header
directly avoids depending on the `file` and `otool` utilities, neither of which
is guaranteed to exist on the host that is fetching a Swift package.
"""

load(":link_types.bzl", "link_types")

# The magic byte sequences that can appear at the start of a framework binary.
# Each is a `list` of lowercase hexadecimal byte `string` values.

# The first four bytes of the `!<arch>\n` ar archive magic.
_AR_MAGIC = ["21", "3c", "61", "72"]

# A Mach-O header stores its fields in the byte order implied by its magic.
# MH_MAGIC and MH_MAGIC_64 mean the fields are little endian. MH_CIGAM and
# MH_CIGAM_64 mean they are big endian.
_MACH_O_LE_MAGICS = [
    ["cf", "fa", "ed", "fe"],  # MH_MAGIC_64
    ["ce", "fa", "ed", "fe"],  # MH_MAGIC
]

_MACH_O_BE_MAGICS = [
    ["fe", "ed", "fa", "cf"],  # MH_CIGAM_64
    ["fe", "ed", "fa", "ce"],  # MH_CIGAM
]

# Universal ("fat") binaries wrap one or more thin slices. Their headers are
# always big endian.
_FAT_MAGIC = ["ca", "fe", "ba", "be"]
_FAT_MAGIC_64 = ["ca", "fe", "ba", "bf"]

# The offset of the `filetype` field in a Mach-O header, relative to the start
# of the header: magic (4) + cputype (4) + cpusubtype (4).
_MACH_O_FILETYPE_OFFSET = 12

# The offset of the first slice's `offset` field in a fat header, relative to
# the start of the header: magic (4) + nfat_arch (4) + cputype (4) +
# cpusubtype (4).
_FAT_ARCH_OFFSET_OFFSET = 16

# The size of the `offset` field in a `fat_arch` (32-bit) and a `fat_arch_64`.
_FAT_ARCH_OFFSET_SIZE = 4
_FAT_ARCH_64_OFFSET_SIZE = 8

# The number of bytes needed to interpret any header this module understands:
# a Mach-O header through its `filetype` field (16 bytes), and a fat header
# through the first slice's 64-bit `offset` field (24 bytes). The whole prefix
# is read in a single call so that each header costs one `od` invocation
# instead of one per field.
_HEADER_PREFIX_SIZE = 24

# The Mach-O `filetype` values that describe a dynamically linked library.
# MH_DYLIB is the common case. MH_DYLIB_STUB is a shared library stub, which
# carries the same LC_ID_DYLIB identification but no section contents.
_MH_DYLIB = 6
_MH_DYLIB_STUB = 9

_HEX_DIGITS = {
    "0": 0,
    "1": 1,
    "2": 2,
    "3": 3,
    "4": 4,
    "5": 5,
    "6": 6,
    "7": 7,
    "8": 8,
    "9": 9,
    "a": 10,
    "b": 11,
    "c": 12,
    "d": 13,
    "e": 14,
    "f": 15,
}

def _uint_be(hex_bytes):
    """Interpret hexadecimal bytes as a big-endian unsigned integer.

    Args:
        hex_bytes: A `list` of lowercase hexadecimal byte `string` values.

    Returns:
        An `int` value.
    """
    value = 0
    for hex_byte in hex_bytes:
        for digit in hex_byte.elems():
            digit_value = _HEX_DIGITS.get(digit)
            if digit_value == None:
                fail("Expected a hexadecimal byte value. Got '{}'.".format(
                    hex_byte,
                ))
            value = value * 16 + digit_value
    return value

def _uint_le(hex_bytes):
    """Interpret hexadecimal bytes as a little-endian unsigned integer.

    Args:
        hex_bytes: A `list` of lowercase hexadecimal byte `string` values.

    Returns:
        An `int` value.
    """
    return _uint_be(reversed(hex_bytes))

def _field(header, header_offset, start, size):
    """Extract a field from a header prefix.

    Args:
        header: The header prefix as a `list` of hexadecimal byte `string`
            values.
        header_offset: The offset the prefix was read from as an `int`. Used
            for error reporting.
        start: The offset of the field within the header as an `int`.
        size: The size of the field in bytes as an `int`.

    Returns:
        A `list` of lowercase hexadecimal byte `string` values.
    """
    end = start + size
    if len(header) < end:
        fail("""\
The header at offset {header_offset} is truncated. Expected at least {end} \
byte(s), read {actual}.\
""".format(actual = len(header), end = end, header_offset = header_offset))
    return header[start:end]

def _mach_o_link_type(header, header_offset, big_endian):
    """Determine the link type from the `filetype` in a Mach-O header.

    Args:
        header: The header prefix as a `list` of hexadecimal byte `string`
            values.
        header_offset: The offset of the Mach-O header as an `int`.
        big_endian: A `bool` specifying whether the header fields are stored
            big endian.

    Returns:
        A `string` value from `link_types`.
    """
    filetype_bytes = _field(
        header,
        header_offset,
        _MACH_O_FILETYPE_OFFSET,
        4,
    )
    if big_endian:
        filetype = _uint_be(filetype_bytes)
    else:
        filetype = _uint_le(filetype_bytes)

    # These are the file types that carry an LC_ID_DYLIB load command, which is
    # what this determination used to look for by way of `otool`. Everything
    # else (MH_OBJECT, MH_EXECUTE, MH_BUNDLE, etc.) is statically linked.
    if filetype == _MH_DYLIB or filetype == _MH_DYLIB_STUB:
        return link_types.dynamic
    return link_types.static

def _link_type(read_bytes):
    """Determine how a binary is linked by inspecting its header.

    Args:
        read_bytes: A `function` that accepts an offset `int` and a count `int`
            and returns up to that many bytes from the binary, starting at the
            offset, as a `list` of lowercase hexadecimal byte `string` values.
            Fewer bytes are returned when the file ends first.

    Returns:
        A `string` value from `link_types`.
    """

    # A fat binary wraps thin slices and cannot itself be nested inside another
    # fat binary, so the header chain is at most two links long. Starlark does
    # not permit recursion, so the chain is walked with a bounded loop.
    offset = 0
    for _ in range(2):
        header = read_bytes(offset, _HEADER_PREFIX_SIZE)
        magic = _field(header, offset, 0, 4)
        if magic == _AR_MAGIC:
            return link_types.static
        elif magic in _MACH_O_LE_MAGICS:
            return _mach_o_link_type(header, offset, big_endian = False)
        elif magic in _MACH_O_BE_MAGICS:
            return _mach_o_link_type(header, offset, big_endian = True)
        elif magic == _FAT_MAGIC or magic == _FAT_MAGIC_64:
            if magic == _FAT_MAGIC_64:
                size = _FAT_ARCH_64_OFFSET_SIZE
            else:
                size = _FAT_ARCH_OFFSET_SIZE
            slice_offset = _uint_be(_field(
                header,
                offset,
                _FAT_ARCH_OFFSET_OFFSET,
                size,
            ))

            # A slice can never start at the beginning of the file, where the
            # fat header itself lives. Catch it here so that a malformed or
            # truncated header does not read as a nested universal binary.
            if slice_offset == 0:
                fail("""\
The first slice of the universal binary has an offset of zero. Please file a \
bug at https://github.com/cgrindel/rules_swift_package_manager/issues/new/choose.\
""")
            offset = slice_offset
        else:
            fail("""\
Unrecognized magic bytes ({magic}) at offset {offset}. Please file a bug at \
https://github.com/cgrindel/rules_swift_package_manager/issues/new/choose.\
""".format(magic = " ".join(magic), offset = offset))

    fail("""\
Found a universal binary nested inside a universal binary. Please file a bug at \
https://github.com/cgrindel/rules_swift_package_manager/issues/new/choose.\
""")

mach_o = struct(
    link_type = _link_type,
    # Exposed for testing purposes only.
    uint_be = _uint_be,
    uint_le = _uint_le,
)
