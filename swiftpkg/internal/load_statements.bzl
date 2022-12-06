"""Module for creating and managing Starlark load statements."""

load("@bazel_skylib//lib:sets.bzl", "sets")

def _new(location, symbols):
    """Create a load statement `struct`.

    The list of symbols will be sorted and uniquified.

    Args:
        location: A `string` representing the location of a Starlark file.
        symbols: A `sequence` of symbols to be loaded from the location.

    Returns:
        A `struct` that includes the location and the cleaned up symbols.
    """
    if len(symbols) < 1:
        fail("""\
Expected at least one symbol to be specified. location: {location}\
""".format(location = location))

    # Get a unique set
    symbols_set = sets.make(symbols)
    new_symbols = sorted(sets.to_list(symbols_set))
    return struct(
        location = location,
        symbols = new_symbols,
    )

load_statements = struct(
    new = _new,
)
