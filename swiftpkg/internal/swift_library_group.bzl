"""A swift_library_group that transitions to a target Apple platform.

NOTE: this maintains the same name as the upstream swift_library_group rule in
order to avoid breaking usage that expects on the rule name.
"""

load("@build_bazel_rules_apple//apple/internal:transition_support.bzl", "transition_support")
load("@build_bazel_rules_swift//swift:swift.bzl", upstream_swift_library_group = "swift_library_group")

def _swift_library_group_impl(ctx):
    return ctx.super()

swift_library_group = rule(
    implementation = _swift_library_group_impl,
    parent = upstream_swift_library_group,
    cfg = transition_support.apple_rule_transition,
    attrs = {
        "minimum_os_version": attr.string(doc = "Internal attribute to set the minimum OS version for the target"),
        "platform_type": attr.string(doc = "Internal attribute to transition to target platform"),
    },
)
