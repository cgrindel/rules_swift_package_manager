"""Defines a struct to hold test information for gazelle generation tests."""

def _new(binary, local, timeout):
    """Creates a struct with test-specific parameters.

    Args:
        binary: The label of the gazelle binary
        local: A `bool` indicating whether the test should be run outside of
            the test sandbox.
        timeout: The timeout in seconds that gazelle should run.

    Returns:
        A `struct` representing the test info.
    """
    return struct(
        binary = binary,
        local = local,
        timeout = timeout,
    )

test_infos = struct(
    new = _new,
)
