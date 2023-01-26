"""Module for Bazel compilation modes."""

compilation_modes = struct(
    debug = "dbg",
    optimized = "opt",
    fast = "fastbuild",
    all_values = [
        "dbg",
        "opt",
        "fastbuild",
    ],
)
