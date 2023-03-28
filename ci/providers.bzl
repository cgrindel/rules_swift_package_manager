CIIntegrationTestParamsInfo = provider(
    doc = "Describes the CI conditions for running a list of integration tests.",
    fields = {
        "bzlmod_modes": "A `list` of bzlmod modes.",
        "oss": "A `list` of operating systems.",
        "tests": "A `list` of integration test labels.",
    },
)
