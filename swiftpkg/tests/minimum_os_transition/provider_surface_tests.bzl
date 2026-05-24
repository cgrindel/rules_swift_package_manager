"""Analysis tests for the minimum OS transition wrapper provider surface."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@build_bazel_rules_apple//apple:providers.bzl", "AppleDynamicFrameworkInfo", "AppleFrameworkImportInfo")
load("@build_bazel_rules_swift//swift:providers.bzl", "SwiftInfo")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _forwards_swift_c_providers_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    asserts.true(env, DefaultInfo in target)
    asserts.true(env, CcInfo in target)
    asserts.true(env, SwiftInfo in target)
    asserts.true(env, OutputGroupInfo in target)

    files = target[DefaultInfo].files.to_list()
    asserts.equals(env, 1, len(files))
    asserts.equals(env, "swift_c_actual.txt", files[0].basename)

    output_group_files = target[OutputGroupInfo].spm_minimum_os_fixture.to_list()
    asserts.equals(env, 1, len(output_group_files))
    asserts.equals(env, "swift_c_actual.output-group.txt", output_group_files[0].basename)

    return analysistest.end(env)

forwards_swift_c_providers_test = analysistest.make(_forwards_swift_c_providers_test_impl)

def _forwards_executable_default_info_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    asserts.true(env, SwiftInfo in target)
    asserts.true(env, RunEnvironmentInfo in target)
    asserts.true(env, testing.ExecutionInfo in target)

    asserts.equals(env, {"SPM_WRAPPER_FIXTURE": "1"}, target[RunEnvironmentInfo].environment)
    asserts.equals(env, {"requires-darwin": ""}, target[testing.ExecutionInfo].requirements)

    default_info = target[DefaultInfo]
    asserts.equals(env, "executable_wrapped", default_info.files_to_run.executable.basename)

    files = target[DefaultInfo].files.to_list()
    basenames = sorted([
        file.basename
        for file in files
    ])
    asserts.equals(env, [
        "executable_actual.default-file.txt",
        "executable_wrapped",
    ], basenames)

    default_runfiles = sorted([
        file.basename
        for file in default_info.default_runfiles.files.to_list()
    ])
    asserts.true(env, "executable_actual.default-runfile.txt" in default_runfiles)
    asserts.true(env, "executable_wrapped" in default_runfiles)

    data_runfiles = sorted([
        file.basename
        for file in default_info.data_runfiles.files.to_list()
    ])
    asserts.equals(env, [
        "executable_actual.data-runfile.txt",
        "executable_wrapped",
    ], data_runfiles)

    return analysistest.end(env)

forwards_executable_default_info_test = analysistest.make(_forwards_executable_default_info_test_impl)

def _forwards_swift_interop_from_dep_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    asserts.true(env, SwiftInfo in target)

    module_names = [
        module.name
        for module in target[SwiftInfo].direct_modules
    ]
    asserts.equals(env, ["CustomModule"], module_names)

    return analysistest.end(env)

forwards_swift_interop_from_dep_test = analysistest.make(_forwards_swift_interop_from_dep_test_impl)

def _forwards_apple_framework_import_provider_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    asserts.true(env, AppleDynamicFrameworkInfo in target)
    asserts.true(env, CcInfo in target)
    asserts.true(env, AppleFrameworkImportInfo in target)

    return analysistest.end(env)

forwards_apple_framework_import_provider_test = analysistest.make(_forwards_apple_framework_import_provider_test_impl)

def provider_surface_test_suite(name):
    """Defines the provider-surface analysis test suite.

    Args:
        name: The name of the native test suite.
    """

    forwards_swift_c_providers_test(
        name = "{}_test_0".format(name),
        target_under_test = ":swift_c_wrapped",
    )
    forwards_swift_interop_from_dep_test(
        name = "{}_test_1".format(name),
        target_under_test = ":custom_module_wrapped",
    )
    forwards_executable_default_info_test(
        name = "{}_test_2".format(name),
        target_under_test = ":executable_wrapped",
    )
    forwards_apple_framework_import_provider_test(
        name = "{}_test_3".format(name),
        target_under_test = ":apple_framework_import_wrapped",
    )
    native.test_suite(
        name = name,
        tests = [
            ":{}_test_0".format(name),
            ":{}_test_1".format(name),
            ":{}_test_2".format(name),
            ":{}_test_3".format(name),
        ],
    )
