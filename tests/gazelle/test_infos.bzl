"""Defines a struct to hold test information for gazelle generation tests."""

def _new(binary, local):
    return struct(
        binary = binary,
        local = local,
    )

test_infos = struct(
    new = _new,
)
