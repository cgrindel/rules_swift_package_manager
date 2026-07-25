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
            "0:24": ["cf", "fa", "ed", "fe", "0c", "00", "00", "01", "00", "00", "00", "00", "06", "00", "00", "00", "0e", "00", "00", "00", "90", "02", "00", "00"],
        },
    ),
    struct(
        name = "thin_object",
        exp_link_type = "static",
        reads = {
            "0:24": ["cf", "fa", "ed", "fe", "0c", "00", "00", "01", "00", "00", "00", "00", "01", "00", "00", "00", "04", "00", "00", "00", "68", "01", "00", "00"],
        },
    ),
    struct(
        name = "thin_archive",
        exp_link_type = "static",
        reads = {
            "0:24": ["21", "3c", "61", "72", "63", "68", "3e", "0a", "23", "31", "2f", "32", "30", "20", "20", "20", "20", "20", "20", "20", "20", "20", "20", "20"],
        },
    ),
    struct(
        name = "fat_dylib",
        exp_link_type = "dynamic",
        reads = {
            "0:24": ["ca", "fe", "ba", "be", "00", "00", "00", "02", "01", "00", "00", "07", "00", "00", "00", "03", "00", "00", "10", "00", "00", "00", "10", "80"],
            "4096:24": ["cf", "fa", "ed", "fe", "07", "00", "00", "01", "03", "00", "00", "00", "06", "00", "00", "00", "0d", "00", "00", "00", "80", "02", "00", "00"],
        },
    ),
    struct(
        name = "fat_archive",
        exp_link_type = "static",
        reads = {
            "0:24": ["ca", "fe", "ba", "be", "00", "00", "00", "02", "01", "00", "00", "07", "00", "00", "00", "03", "00", "00", "00", "30", "00", "00", "03", "38"],
            "48:24": ["21", "3c", "61", "72", "63", "68", "3e", "0a", "23", "31", "2f", "32", "30", "20", "20", "20", "20", "20", "20", "20", "20", "20", "20", "20"],
        },
    ),
    struct(
        name = "fat64_dylib",
        exp_link_type = "dynamic",
        reads = {
            "0:24": ["ca", "fe", "ba", "bf", "00", "00", "00", "02", "01", "00", "00", "07", "00", "00", "00", "03", "00", "00", "00", "00", "00", "00", "10", "00"],
            "4096:24": ["cf", "fa", "ed", "fe", "07", "00", "00", "01", "03", "00", "00", "00", "06", "00", "00", "00", "0d", "00", "00", "00", "80", "02", "00", "00"],
        },
    ),
    struct(
        name = "symlinked_dylib",
        exp_link_type = "dynamic",
        reads = {
            "0:24": ["cf", "fa", "ed", "fe", "0c", "00", "00", "01", "00", "00", "00", "00", "06", "00", "00", "00", "0e", "00", "00", "00", "90", "02", "00", "00"],
        },
    ),
]
