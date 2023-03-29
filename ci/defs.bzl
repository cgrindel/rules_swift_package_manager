"""Public API for CI workflow generation."""

load("//ci/internal:bzlmod_modes.bzl", _bzlmod_modes = "bzlmod_modes")
load(
    "//ci/internal:ci_integration_test_params.bzl",
    _ci_integration_test_params = "ci_integration_test_params",
)
load("//ci/internal:ci_workflow.bzl", _ci_workflow = "ci_workflow")
load(
    "//ci/internal:providers.bzl",
    _CITestParamsInfo = "CITestParamsInfo",
)

# Modules
bzlmod_modes = _bzlmod_modes

# Rules
ci_integration_test_params = _ci_integration_test_params
ci_workflow = _ci_workflow

# Providers
CITestParamsInfo = _CITestParamsInfo
