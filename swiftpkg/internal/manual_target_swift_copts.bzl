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

def _targets_by_config_name(pkg_info):
    targets_by_name = {}
    for target in pkg_info.targets:
        if target.swift_src_info == None:
            continue
        for name in _names_for_target(target):
            targets = targets_by_name.get(name, {})
            targets[target.name] = True
            targets_by_name[name] = targets
    return targets_by_name

def _validation_error(pkg_info, target_swift_copts):
    if not target_swift_copts:
        return None

    targets_by_name = _targets_by_config_name(pkg_info)
    unknown_names = depset([
        config["target"]
        for config in target_swift_copts
        if config["target"] not in targets_by_name
    ]).to_list()
    if unknown_names:
        return """\
Swift compiler options were configured for unknown or non-Swift targets: \
{unknown}. Valid Swift targets are: {valid}.\
""".format(
            unknown = ", ".join(sorted(unknown_names)),
            valid = ", ".join(sorted(targets_by_name.keys())),
        )

    ambiguous_names = depset([
        config["target"]
        for config in target_swift_copts
        if len(targets_by_name[config["target"]]) > 1
    ]).to_list()
    if ambiguous_names:
        return """\
Swift compiler option target selectors must each identify exactly one generated \
target. Ambiguous selectors: {ambiguities}. Use an unambiguous raw or generated \
target name.\
""".format(
            ambiguities = "; ".join([
                "'{}' matched {}".format(
                    name,
                    ", ".join(sorted(targets_by_name[name].keys())),
                )
                for name in sorted(ambiguous_names)
            ]),
        )
    return None

def _validate(pkg_info, target_swift_copts):
    error = _validation_error(pkg_info, target_swift_copts)
    if error:
        fail(error)

manual_target_swift_copts = struct(
    copts_for_target = _copts_for_target,
    validate = _validate,
    validation_error = _validation_error,
)
