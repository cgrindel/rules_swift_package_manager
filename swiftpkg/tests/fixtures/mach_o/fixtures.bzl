"""Recorded byte reads for the Mach-O fixtures.

DO NOT EDIT. Regenerate with:

    swiftpkg/tests/fixtures/mach_o/gen_fixtures.sh

Each entry records the bytes that `mach_o.link_type` reads from the
corresponding fixture, keyed by `"<offset>:<count>"`, along with the link type
that the `file` and `otool` utilities report for it. `verify_fixtures.sh`
re-reads the fixtures with `od` and fails if these recordings drift, which is
what keeps them honest on both Linux and macOS.
"""

MACH_O_FIXTURES = [
    struct(
        name = "thin_dylib",
        exp_link_type = "dynamic",
        reads = {
            "0:4": ["cf", "fa", "ed", "fe"],
            "12:4": ["06", "00", "00", "00"],
        },
    ),
    struct(
        name = "thin_object",
        exp_link_type = "static",
        reads = {
            "0:4": ["cf", "fa", "ed", "fe"],
            "12:4": ["01", "00", "00", "00"],
        },
    ),
    struct(
        name = "thin_archive",
        exp_link_type = "static",
        reads = {
            "0:4": ["21", "3c", "61", "72"],
        },
    ),
    struct(
        name = "fat_dylib",
        exp_link_type = "dynamic",
        reads = {
            "0:4": ["ca", "fe", "ba", "be"],
            "16:4": ["00", "00", "10", "00"],
            "4096:4": ["cf", "fa", "ed", "fe"],
            "4108:4": ["06", "00", "00", "00"],
        },
    ),
    struct(
        name = "fat_archive",
        exp_link_type = "static",
        reads = {
            "0:4": ["ca", "fe", "ba", "be"],
            "16:4": ["00", "00", "00", "30"],
            "48:4": ["21", "3c", "61", "72"],
        },
    ),
    struct(
        name = "fat64_dylib",
        exp_link_type = "dynamic",
        reads = {
            "0:4": ["ca", "fe", "ba", "bf"],
            "16:8": ["00", "00", "00", "00", "00", "00", "10", "00"],
            "4096:4": ["cf", "fa", "ed", "fe"],
            "4108:4": ["06", "00", "00", "00"],
        },
    ),
    struct(
        name = "symlinked_dylib",
        exp_link_type = "dynamic",
        reads = {
            "0:4": ["cf", "fa", "ed", "fe"],
            "12:4": ["06", "00", "00", "00"],
        },
    ),
]
