"""Minimum OS transition wrapper for Swift package targets."""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleDynamicFrameworkInfo",
    "AppleFrameworkImportInfo",
    "AppleResourceInfo",
)
load("@build_bazel_rules_swift//swift:providers.bzl", "SwiftBinaryInfo", "SwiftInfo")
load("@build_bazel_rules_swift//swift:swift_clang_module_aspect.bzl", "swift_clang_module_aspect")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(":minimum_os_platforms.bzl", "minimum_os_platforms")

_APPLE_PLATFORM_TYPE_OPTION = "//command_line_option:apple_platform_type"

_MINIMUM_OS_VERSION_OPTION = "//command_line_option:minimum_os_version"

# Supported Bazel apple_platform_type values match normalized SwiftPM platform
# names, so the transition can use the shared platform config map directly.
_MINIMUM_OS_CONFIG_BY_PLATFORM_TYPE = minimum_os_platforms.by_platform()

# _MINIMUM_OS_VERSION_OPTION is already included in _MINIMUM_OS_OPTIONS from
# the visionOS platform. _MINIMUM_OS_VERSION_OPTION will need to be appended to
# _MINIMUM_OS_OPTIONS explicitly if/when visionOS gets a dedicated flag.
_MINIMUM_OS_OPTIONS = minimum_os_platforms.options()

def _transition_outputs(settings, attr):
    outputs = {
        option: settings[option]
        for option in _MINIMUM_OS_OPTIONS
    }

    platform_type = settings[_APPLE_PLATFORM_TYPE_OPTION]
    minimum_os_config = _MINIMUM_OS_CONFIG_BY_PLATFORM_TYPE.get(platform_type)
    if minimum_os_config == None:
        return outputs

    attr_name = minimum_os_config.attr_name
    minimum_os = getattr(attr, attr_name)
    if not minimum_os:
        fail("{} requires {} when --apple_platform_type={}".format(
            getattr(attr, "name", "<unknown>"),
            attr_name,
            platform_type,
        ))

    import_error = _import_error(
        target_name = getattr(attr, "name", "<unknown>"),
        platform_type = platform_type,
        importer_minimum_os = settings[minimum_os_config.option],
        imported_minimum_os = minimum_os,
    )
    if import_error:
        fail(import_error)

    outputs[minimum_os_config.option] = minimum_os

    # Set the minimum_os_version flag in addition to the OS specific flag
    outputs[_MINIMUM_OS_VERSION_OPTION] = minimum_os

    return outputs

def _version_string(value):
    return str(value) if value else value

def _version_tuple(value):
    components = _version_string(value).split(".") + ["0", "0", "0"]
    return tuple([int(x if x.isdigit() else "0") for x in components[0:3]])

def _import_error(target_name, platform_type, importer_minimum_os, imported_minimum_os):
    importer_minimum_os = _version_string(importer_minimum_os)
    if not importer_minimum_os:
        return None
    if _version_tuple(importer_minimum_os) >= _version_tuple(imported_minimum_os):
        return None

    return """\
The target '{target_name}' requires {platform_type} {imported_minimum_os}, but \
is being imported from a target configured for {platform_type} \
{importer_minimum_os}; consider raising the importing target's minimum OS to \
{imported_minimum_os} or later.\
""".format(
        target_name = target_name,
        platform_type = platform_type,
        importer_minimum_os = importer_minimum_os,
        imported_minimum_os = imported_minimum_os,
    )

_spm_minimum_os_transition = transition(
    implementation = _transition_outputs,
    inputs = [_APPLE_PLATFORM_TYPE_OPTION] + _MINIMUM_OS_OPTIONS,
    outputs = _MINIMUM_OS_OPTIONS,
)

def _forwarded_providers(actual, default_info = None):
    providers = [default_info or actual[DefaultInfo]]

    for provider in [
        AppleDynamicFrameworkInfo,
        AppleFrameworkImportInfo,
        AppleResourceInfo,
        CcInfo,
        RunEnvironmentInfo,
        SwiftInfo,
        SwiftBinaryInfo,
        testing.ExecutionInfo,
        OutputGroupInfo,
        InstrumentedFilesInfo,
    ]:
        if provider in actual:
            providers.append(actual[provider])

    if hasattr(apple_common, "Objc") and apple_common.Objc in actual:
        providers.append(actual[apple_common.Objc])

    return providers

def _spm_minimum_os_target_impl(ctx):
    actual = _actual(ctx)
    return _forwarded_providers(actual)

def _spm_minimum_os_executable_impl(ctx):
    actual = _actual(ctx)
    default_info = actual[DefaultInfo]
    actual_executable = default_info.files_to_run.executable
    if actual_executable == None:
        fail("Expected dep target '{}' to provide an executable.".format(
            actual.label,
        ))

    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(
        output = executable,
        target_file = actual_executable,
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [executable])

    return _forwarded_providers(
        actual,
        default_info = DefaultInfo(
            executable = executable,
            files = depset([executable], transitive = [default_info.files]),
            default_runfiles = default_info.default_runfiles.merge(runfiles),
            data_runfiles = default_info.data_runfiles.merge(runfiles),
        ),
    )

def _actual(ctx):
    if len(ctx.attr.deps) != 1:
        fail("{} requires exactly one dep.".format(ctx.label))

    return ctx.attr.deps[0]

_minimum_os_attrs = {
    "deps": attr.label_list(
        aspects = [swift_clang_module_aspect],
        mandatory = True,
        cfg = _spm_minimum_os_transition,
        doc = "Single-element list whose target is built under the package minimum OS transition.",
    ),
    "ios_minimum_os": attr.string(
        doc = "The package minimum deployment target for iOS.",
    ),
    "macos_minimum_os": attr.string(
        doc = "The package minimum deployment target for macOS.",
    ),
    "tvos_minimum_os": attr.string(
        doc = "The package minimum deployment target for tvOS.",
    ),
    "visionos_minimum_os": attr.string(
        doc = "The package minimum deployment target for visionOS.",
    ),
    "watchos_minimum_os": attr.string(
        doc = "The package minimum deployment target for watchOS.",
    ),
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
}

spm_minimum_os_target = rule(
    implementation = _spm_minimum_os_target_impl,
    attrs = _minimum_os_attrs,
    doc = "Applies Swift package minimum OS settings to an implementation target.",
)

spm_minimum_os_binary = rule(
    implementation = _spm_minimum_os_executable_impl,
    attrs = _minimum_os_attrs,
    executable = True,
    doc = "Applies Swift package minimum OS settings to an executable implementation target.",
)

spm_minimum_os_test = rule(
    implementation = _spm_minimum_os_executable_impl,
    attrs = _minimum_os_attrs,
    test = True,
    doc = "Applies Swift package minimum OS settings to a test implementation target.",
)

minimum_os_transition = struct(
    import_error = _import_error,
    transition_outputs = _transition_outputs,
)
