"""Implementation for the `ci_workflow` rule."""

load("@cgrindel_bazel_starlib//updatesrc:defs.bzl", "updatesrc_diff_and_update")
load(":bzlmod_modes.bzl", "bzlmod_modes")
load(":providers.bzl", "CIIntegrationTestParamsInfo")

def _integration_test_params(test, os, enable_bzlmod):
    return struct(
        test = str(test),
        os = os,
        enable_bzlmod = enable_bzlmod,
    )

def _ci_workflow_impl(ctx):
    # Collect all of the tests
    test_params = []
    for itp in ctx.attr.integration_test_params:
        test_params_info = itp[CIIntegrationTestParamsInfo]
        for test in test_params_info.tests:
            for os in test_params_info.oss:
                for bzlmod_mode in test_params_info.bzlmod_modes:
                    test_params.append(_integration_test_params(
                        test = test,
                        os = os,
                        enable_bzlmod = bzlmod_modes.to_bool(bzlmod_mode),
                    ))

    # Generate JSON describing all of the integration tests
    json_file = ctx.actions.declare_file("{}_test_params.json".format(ctx.label.name))
    json_str = json.encode_indent(test_params)
    ctx.actions.write(json_file, json_str)

    # Generate the CI workflow
    workflow_out = ctx.actions.declare_file("{}.yml".format(ctx.label.name))
    args = ctx.actions.args()
    args.add("-template", ctx.file.template)
    args.add("-int_test_params_json", json_file)
    args.add("-output", workflow_out)

    ctx.actions.run(
        outputs = [workflow_out],
        inputs = [json_file, ctx.file.template],
        executable = ctx.executable._workflow_generator,
        arguments = [args],
    )

    return [
        DefaultInfo(files = depset([workflow_out])),
    ]

_ci_workflow = rule(
    implementation = _ci_workflow_impl,
    attrs = {
        "integration_test_params": attr.label_list(
            mandatory = True,
            providers = [[CIIntegrationTestParamsInfo]],
            doc = "The integration tests that should be included in the CI workflow.",
        ),
        "template": attr.label(
            allow_single_file = [".yml", ".yaml"],
            mandatory = True,
            doc = "The current worklfow yaml file.",
        ),
        "_workflow_generator": attr.label(
            default = Label("//tools/generate_ci_workflow"),
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
    },
    doc = """\
Generate a GitHub workflow file with jobs for each of the integration test \
parameter permutations.\
""",
)

def ci_workflow(name, workflow_yml, integration_test_params, **kwargs):
    """Generates a GitHub workflow file with jobs for each of the listed \
    integration test parameter permutations.

    In addition to building the worklfow YAML file, it also defines a target
    that compares the generated file with the version in the source tree. If
    they do not match, the test will fail. This macro also provides a runnable
    target for updating the source tree with the generated workflow file.

    Args:
        name: The name of the build target as a `string`.
        workflow_yml: The path to the GitHub workflow file in the source tree.
            This can be a `string` or a `Label`.
        integration_test_params: A `sequence` of labels that provide
            `CIIntegrationTestParamsInfo` (e.g., `ci_integration_test_params`).
        **kwargs: Common attributes that are passed to the build target.

    Returns:
    """
    _ci_workflow(
        name = name,
        template = workflow_yml,
        integration_test_params = integration_test_params,
        **kwargs
    )
    updatesrc_diff_and_update(
        name = "update_" + name,
        srcs = [workflow_yml],
        outs = [name],
    )
