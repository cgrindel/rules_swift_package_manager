"""Module containing helpers for defining integration tests."""

load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "integration_test_utils",
)

def _integration_test_names(base_names, versions):
    """Creates a list of integration test names

    Args:
        base_names: A `list` of test base names.
        versions: A `list` of Bazel versions.

    Returns:
        A `list` of test names.
    """
    all_names = []
    for base_name in base_names:
        all_names.extend(
            integration_test_utils.bazel_integration_test_names(
                base_name,
                versions,
            ),
        )
    return all_names

test_utils = struct(
    integration_test_names = _integration_test_names,
)
