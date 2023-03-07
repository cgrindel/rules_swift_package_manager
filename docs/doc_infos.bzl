"""Module for organizing documentation."""

def _new(name, label, symbols):
    return struct(
        name = name,
        label = label,
        symbols = symbols,
    )

doc_infos = struct(
    new = _new,
)
