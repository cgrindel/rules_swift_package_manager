"""Fixtures for minimum OS transition tests."""

load("@build_bazel_rules_apple//apple:providers.bzl", "AppleDynamicFrameworkInfo", "apple_provider")
load("@build_bazel_rules_swift//swift:providers.bzl", "SwiftInfo")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _swift_c_provider_target_impl(ctx):
    default_file = ctx.actions.declare_file("{}.txt".format(ctx.attr.name))
    output_group_file = ctx.actions.declare_file("{}.output-group.txt".format(ctx.attr.name))

    ctx.actions.write(
        output = default_file,
        content = ctx.label.name,
    )
    ctx.actions.write(
        output = output_group_file,
        content = ctx.label.name,
    )

    return [
        DefaultInfo(files = depset([default_file])),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(),
            linking_context = cc_common.create_linking_context(
                linker_inputs = depset(),
            ),
        ),
        SwiftInfo(
            modules = [],
        ),
        OutputGroupInfo(
            spm_minimum_os_fixture = depset([output_group_file]),
        ),
    ]

swift_c_provider_target = rule(
    implementation = _swift_c_provider_target_impl,
)

def _executable_provider_target_impl(ctx):
    executable_file = ctx.actions.declare_file(ctx.attr.name)
    default_file = ctx.actions.declare_file("{}.default-file.txt".format(ctx.attr.name))
    default_runfile = ctx.actions.declare_file("{}.default-runfile.txt".format(ctx.attr.name))
    data_runfile = ctx.actions.declare_file("{}.data-runfile.txt".format(ctx.attr.name))

    ctx.actions.write(
        output = executable_file,
        content = "#!/bin/sh\n",
        is_executable = True,
    )
    ctx.actions.write(
        output = default_file,
        content = ctx.label.name,
    )
    ctx.actions.write(
        output = default_runfile,
        content = ctx.label.name,
    )
    ctx.actions.write(
        output = data_runfile,
        content = ctx.label.name,
    )

    return [
        DefaultInfo(
            executable = executable_file,
            files = depset([default_file]),
            default_runfiles = ctx.runfiles(files = [default_runfile]),
            data_runfiles = ctx.runfiles(files = [data_runfile]),
        ),
        RunEnvironmentInfo(
            environment = {"SPM_WRAPPER_FIXTURE": "1"},
        ),
        SwiftInfo(
            modules = [],
        ),
        testing.ExecutionInfo(
            requirements = {"requires-darwin": ""},
        ),
    ]

executable_provider_target = rule(
    implementation = _executable_provider_target_impl,
    executable = True,
)

def _spm_provider_consumer_impl(ctx):
    return [ctx.attr.dep[DefaultInfo]]

spm_provider_consumer = rule(
    implementation = _spm_provider_consumer_impl,
    attrs = {
        "dep": attr.label(
            mandatory = True,
            providers = [[CcInfo, SwiftInfo]],
        ),
    },
)

def _apple_framework_import_provider_target_impl(_ctx):
    cc_info = CcInfo(
        compilation_context = cc_common.create_compilation_context(),
        linking_context = cc_common.create_linking_context(
            linker_inputs = depset(),
        ),
    )
    return [
        DefaultInfo(),
        cc_info,
        AppleDynamicFrameworkInfo(cc_info = cc_info),
        apple_provider.merge_apple_framework_import_info([]),
    ]

apple_framework_import_provider_target = rule(
    implementation = _apple_framework_import_provider_target_impl,
)
