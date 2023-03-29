"""Implementation for the `ci_integration_test_params` rule."""

load(":ci_test_params.bzl", "ci_test_params")
load(":providers.bzl", "CITestParamsInfo")

def _ci_integration_test_params_impl(ctx):
    workspace_name = ctx.label.workspace_name
    package = ctx.label.package
    test_names = [
        name.removeprefix(":")
        for name in ctx.attr.test_names
    ]
    test_labels = [
        Label("@{workspace}//{pkg}:{name}".format(
            workspace = workspace_name,
            pkg = package,
            name = name,
        ))
        for name in test_names
    ]
    itps = []
    for test_label in test_labels:
        for os in ctx.attr.oss:
            for bzlmod_mode in ctx.attr.bzlmod_modes:
                itp = ci_test_params.new_integration_test_params(
                    test = test_label,
                    os = os,
                    bzlmod_mode = bzlmod_mode,
                )
                itps.append(itp)
    return [
        CITestParamsInfo(
            integration_test_params = depset(itps),
        ),
    ]

ci_integration_test_params = rule(
    implementation = _ci_integration_test_params_impl,
    attrs = {
        "bzlmod_modes": attr.string_list(
            default = ["enabled"],
            doc = "Accepted values: `enabled`, `disabled`.",
        ),
        "oss": attr.string_list(
            default = ["macos", "linux"],
            doc = "Accepted values: `macos`, `linux`.",
        ),
        # This cannot be a label_list, because the labels are tests. It would
        # require that this rule and any rules that use this rule would need to
        # be testonly = True. The workflow CI mechanism requires that the
        # output be "buildable".
        "test_names": attr.string_list(
            mandatory = True,
            doc = """\
A list of the test names in this package that should use these parameters.\
""",
        ),
    },
    doc = """\
Describe how one or more integration tests should be executed in CI.\
""",
)
