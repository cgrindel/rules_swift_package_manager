"""Utilities for Swift compiler options configured on generated targets."""

load(":bzl_selects.bzl", "bzl_selects")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":pkginfos.bzl", "target_types")

_configured_copts_kind = "configured_target_swift_copts"

def _names_for_target(target):
    public_label_name = pkginfo_targets.bazel_label_name(target)
    names = [
        target.name,
        public_label_name,
    ]
    if target.type != target_types.macro:
        names.append(pkginfo_targets.implementation_label_name(public_label_name))
    return names

def _copts_for_target(pkg_ctx, target):
    if not hasattr(pkg_ctx, "target_swift_copts"):
        return []

    configured_names = _names_for_target(target)
    copts = []
    for config in pkg_ctx.target_swift_copts:
        if config["target"] not in configured_names:
            continue
        condition = config.get("condition")
        for copt in config["swift_copts"]:
            if condition:
                copts.append(bzl_selects.new(
                    value = copt,
                    kind = _configured_copts_kind,
                    condition = condition,
                ))
            else:
                copts.append(copt)
    return copts

def _valid_names(pkg_info):
    names = []
    for target in pkg_info.targets:
        if target.swift_src_info == None or target.type == target_types.test:
            continue
        names.extend(_names_for_target(target))
    return names

def _validate(pkg_info, target_swift_copts):
    if not target_swift_copts:
        return

    valid_names = _valid_names(pkg_info)
    unknown_names = [
        config["target"]
        for config in target_swift_copts
        if config["target"] not in valid_names
    ]
    if unknown_names:
        fail("""\
Swift compiler options were configured for unknown or non-Swift targets: \
{unknown}. Valid Swift targets are: {valid}.\
""".format(
            unknown = ", ".join(sorted(depset(unknown_names).to_list())),
            valid = ", ".join(sorted(valid_names)),
        ))

manual_target_swift_copts = struct(
    copts_for_target = _copts_for_target,
    validate = _validate,
)
