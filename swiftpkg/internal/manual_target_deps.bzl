"""Utilities for manually configured dependencies on generated targets."""

load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":pkginfos.bzl", "target_types")

def _deps_for_labels(pkg_ctx, label_names):
    if not hasattr(pkg_ctx, "target_deps"):
        return []

    deps = []
    for label_name in label_names:
        deps.extend([
            _translate_dep_value(pkg_ctx, dep)
            for dep in pkg_ctx.target_deps.get(label_name, [])
        ])
    return deps

def _deps_for_generated_target(pkg_ctx, generated_name):
    return _deps_for_labels(pkg_ctx, [generated_name])

def _deps_for_target(pkg_ctx, target):
    public_label_name = pkginfo_targets.bazel_label_name(target)
    return _deps_for_labels(pkg_ctx, [
        target.name,
        pkginfo_targets.implementation_label_name(public_label_name),
    ])

def _target_by_name(pkg_info, name):
    for target in pkg_info.targets:
        if target.name == name:
            return target
    return None

def _translate_local_target_name(pkg_ctx, name, original, prefix):
    target = _target_by_name(pkg_ctx.pkg_info, name)
    if target == None or target.label.package:
        return original

    return "{}{}".format(prefix, target.label.name)

def _translate_dep_value(pkg_ctx, dep):
    if dep.startswith("@") or ".rspm" in dep:
        return dep

    if dep.startswith(":"):
        return _translate_local_target_name(pkg_ctx, dep[1:], dep, ":")

    if dep.startswith("//:"):
        return _translate_local_target_name(pkg_ctx, dep[3:], dep, "//:")

    if dep.startswith("//"):
        return dep

    return _translate_local_target_name(pkg_ctx, dep, dep, ":")

def _product_dep_names(pkg_info, product):
    if product.type.is_plugin or product.type.is_library:
        return []

    if product.type.is_executable:
        if len(product.targets) != 1:
            return []

        target = _target_by_name(pkg_info, product.targets[0])
        if target == None:
            return []

        if target.type == target_types.executable:
            return []

        return [product.name]

    return []

def _clang_child_dep_names(target):
    if target.clang_src_info == None:
        return []

    bzl_target_name = target.label.name
    names = []
    organized_srcs = target.clang_src_info.organized_srcs
    if organized_srcs.c_srcs:
        names.append("{}_c".format(bzl_target_name))
    if organized_srcs.cxx_srcs:
        names.append("{}_cxx".format(bzl_target_name))
    if organized_srcs.assembly_srcs:
        names.append("{}_assembly".format(bzl_target_name))
    if target.objc_src_info != None:
        if organized_srcs.objc_srcs:
            names.append("{}_objc".format(bzl_target_name))
        if organized_srcs.objcxx_srcs:
            names.append("{}_objcxx".format(bzl_target_name))

    return names

def _deps_for_product(pkg_ctx, product):
    return _deps_for_labels(
        pkg_ctx,
        _product_dep_names(pkg_ctx.pkg_info, product),
    )

def _valid_target_dep_names(pkg_info):
    names = []

    for target in pkg_info.targets:
        public_label_name = pkginfo_targets.bazel_label_name(target)
        names.extend([
            target.name,
            pkginfo_targets.implementation_label_name(public_label_name),
        ])
        names.extend(_clang_child_dep_names(target))

    for product in pkg_info.products:
        names.extend(_product_dep_names(pkg_info, product))

    return names

def _validate(pkg_info, target_deps):
    if not target_deps:
        return

    valid_names = _valid_target_dep_names(pkg_info)
    unknown_names = [
        name
        for name in target_deps.keys()
        if name not in valid_names
    ]
    if unknown_names:
        fail("""\
Manual target dependencies were configured for unknown generated targets: \
{unknown}. Valid generated targets are: {valid}.\
""".format(
            unknown = ", ".join(sorted(unknown_names)),
            valid = ", ".join(sorted(valid_names)),
        ))

manual_target_deps = struct(
    deps_for_labels = _deps_for_labels,
    deps_for_generated_target = _deps_for_generated_target,
    deps_for_product = _deps_for_product,
    deps_for_target = _deps_for_target,
    validate = _validate,
)
