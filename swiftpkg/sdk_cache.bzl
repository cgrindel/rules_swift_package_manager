"""Explicit SDK cache generation using the configured Swift toolchain."""

load("@apple_support//lib:apple_support.bzl", "apple_support")
load("@build_bazel_rules_swift//swift:swift_common.bzl", "swift_common")

def _impl(ctx):
    toolchain = swift_common.find_all_toolchains(ctx).swift
    compiler = toolchain.tool_configs["SwiftCompile"]
    descriptor = ctx.actions.declare_file(ctx.label.name + ".toolchain.json")
    args = ctx.actions.args()
    args.add("--capture-toolchain", descriptor)
    args.add("--driver", compiler.executable)
    args.add("--driver-args", json.encode(compiler.args))
    args.add("--developer-dir", apple_support.path_placeholders.xcode())
    apple_support.run(
        actions = ctx.actions,
        apple_fragment = ctx.fragments.apple,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
        executable = ctx.executable._generator,
        arguments = [args],
        outputs = [descriptor],
        env = compiler.env,
        execution_requirements = dict(compiler.execution_requirements, **{"no-remote": "1"}),
        xcode_path_resolve_level = apple_support.xcode_path_resolve_level.args,
        mnemonic = "SDKCacheToolchain",
    )
    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")
    validation = ""
    cache_files = []
    if hasattr(ctx.file, "cache") and ctx.file.cache:
        cache_files = [ctx.file.cache]
        validation = ' --validate "$root/{}/{}"'.format(ctx.workspace_name, ctx.file.cache.short_path)
    ctx.actions.write(
        launcher,
        """#!/usr/bin/env bash
set -euo pipefail
root="${{RUNFILES_DIR:-$0.runfiles}}"
if [[ ! -d "$root" ]]; then
  echo 'SDK cache launcher requires a runfiles directory' >&2
  exit 1
fi
exec "$root/{workspace}/{tool}" --toolchain "$root/{workspace}/{descriptor}"{validation} "$@"
""".format(
            workspace = ctx.workspace_name,
            tool = ctx.executable._generator.short_path,
            descriptor = descriptor.short_path,
            validation = validation,
        ),
        is_executable = True,
    )
    providers = [DefaultInfo(
        executable = launcher,
        runfiles = ctx.runfiles(files = [descriptor, ctx.executable._generator] + cache_files).merge(
            ctx.attr._generator[DefaultInfo].default_runfiles,
        ),
    )]
    if cache_files:
        # The installed SDK is checked at execution time, not an action input.
        providers.append(testing.ExecutionInfo({"local": "1"}))
    return providers

_ATTRS = dict(apple_support.action_required_attrs(), **{
    "_generator": attr.label(
        default = "//tools/sdk_cache",
        executable = True,
        cfg = "exec",
    ),
})

swift_sdk_cache = rule(
    implementation = _impl,
    executable = True,
    attrs = _ATTRS,
    fragments = ["apple", "cpp"],
    toolchains = swift_common.use_all_toolchains(),
    doc = """Create an explicit cache generation/validation executable.

Run with --request SETTINGS.json --output CACHE.json, or --validate CACHE.json.
The target has no dependency on the cache or on generated Swift package repos,
so it can bootstrap or repair missing and stale caches.
""",
)

_swift_sdk_cache_test = rule(
    implementation = _impl,
    test = True,
    attrs = dict(_ATTRS, cache = attr.label(mandatory = True, allow_single_file = [".json"])),
    fragments = ["apple", "cpp"],
    toolchains = swift_common.use_all_toolchains(),
    doc = "Validate a committed SDK cache against Bazel's configured Xcode toolchain at test time.",
)

def swift_sdk_cache_test(name, tags = [], **kwargs):
    """Validate the installed SDK on every test invocation.

    Args:
        name: Test target name.
        tags: Additional test tags.
        **kwargs: Attributes forwarded to the validation rule, including cache.
    """

    # ExecutionInfo controls spawn caching, but not Bazel's test-result cache.
    # The external tag prevents reusing a pass after an in-place SDK change.
    _swift_sdk_cache_test(
        name = name,
        tags = depset(tags + ["external"]).to_list(),
        **kwargs
    )
