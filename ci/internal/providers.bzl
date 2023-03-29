"""Provider definitions for the GitHub CI workflow generation."""

CITestParamsInfo = provider(
    doc = "Collects the test parameters for running CI tests.",
    fields = {
        "integration_test_params": """\
A `depset` of `struct` values as created by `ci_test_params.new_integration_test_params`.\
""",
    },
)
