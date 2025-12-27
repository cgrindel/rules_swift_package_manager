"""Module for creating and managing Starlark load statements."""

load("@bazel_skylib//lib:sets.bzl", "sets")
load(":starlark_codegen.bzl", scg = "starlark_codegen")

def _new(location, *symbols, **kwargs):
    """Create a load statement `struct`.

    The list of symbols will be sorted and uniquified.

    Args:
        location: A `string` representing the location of a Starlark file.
        *symbols: A `sequence` of symbols to be loaded from the location.
        **kwargs: Aliased symbols where the key is the alias and the value is
            the original symbol name.

    Returns:
        A `struct` that includes the location and the cleaned up symbols.
    """
    if len(symbols) < 1 and len(kwargs) < 1:
        fail("""\
Expected at least one symbol to be specified. location: {location}\
""".format(location = location))

    # Get a unique set of regular symbols
    symbols_set = sets.make(symbols)
    new_symbols = sorted(sets.to_list(symbols_set))

    # Process aliased symbols
    aliased_symbols = {k: v for k, v in kwargs.items()}

    return struct(
        location = location,
        symbols = new_symbols,
        aliased_symbols = aliased_symbols,
        to_starlark_parts = _to_starlark_parts,
    )

# buildifier: disable=unused-variable
def _to_starlark_parts(load_stmt, indent):
    parts = [
        "load(",
        scg.normalize(load_stmt.location),
    ]

    # The symbols should already be sorted and deduped.
    for symbol in load_stmt.symbols:
        parts.extend([", ", scg.normalize(symbol)])

    # Handle aliased symbols (alias = "original")
    aliased = getattr(load_stmt, "aliased_symbols", {})
    for alias in sorted(aliased.keys()):
        original = aliased[alias]
        parts.extend([", ", alias, " = ", scg.normalize(original)])

    parts.append(")")
    return parts

def _index(load_stmts):
    index_by_location = {}
    for load_stmt in load_stmts:
        location = load_stmt.location
        existing_values = index_by_location.get(location, [])
        existing_values.append(load_stmt)
        index_by_location[location] = existing_values
    return index_by_location

def _uniq(load_stmts):
    """Sort and dedupe load statements.

    Args:
        load_stmts: A `list` of load statements as created by
            `load_statments.new`.

    Returns:
        A `list` of load statements sorted and deduplicated.
    """
    index_by_location = _index(load_stmts)

    # Collect results in location-sorted order
    results = []
    for location in sorted(index_by_location.keys()):
        existing_values = index_by_location[location]
        symbols = []
        aliased_symbols = {}
        for load_stmt in existing_values:
            symbols.extend(load_stmt.symbols)
            aliased_symbols |= load_stmt.aliased_symbols
        new_load_stmt = _new(location, *symbols, **aliased_symbols)
        results.append(new_load_stmt)

    return results

load_statements = struct(
    new = _new,
    uniq = _uniq,
)
