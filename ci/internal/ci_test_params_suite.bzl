"""Implementation for `ci_test_params_suite` rule."""

def _ci_test_params_suite_impl(ctx):
    itp_depset = ci_test_params.collect_from_deps(ctx.attr.test_params)
    return [CITestParamsInfo(integration_test_params = itp_depset)]

ci_test_params_suite = rule(
    implementation = _ci_test_params_suite_impl,
    attrs = {
        "test_params": attr.label_list(
            mandatory = True,
            providers = [[CITestParamsInfo]],
            doc = "The test params that should be collected.",
        ),
    },
    doc = "Collect the test parameters to pass along as a single target.",
)
