load("@cgrindel_bazel_starlib//updatesrc:defs.bzl", "updatesrc_diff_and_update")
load(":providers.bzl", "CIIntegrationTestParamsInfo")

def _integration_test_params(test, os, enable_bzlmod):
    return struct(
        test = str(test),
        os = os,
        enable_bzlmod = enable_bzlmod,
    )

def _enable_bzlmod(bzlmod_mode):
    if bzlmod_mode == "enabled":
        return True
    elif bzlmod_mode == "disabled":
        return False
    fail("Unrecognized bzlmod_mode: {}".format(bzlmod_mode))

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
                        enable_bzlmod = _enable_bzlmod(bzlmod_mode),
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
            # allow_single_file = [".yml", ".yaml"],
            allow_single_file = True,
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
    doc = "",
)

def ci_workflow(name, workflow_yml, integration_test_params, **kwargs):
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
