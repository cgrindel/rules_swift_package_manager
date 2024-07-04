"""Module for generating data from target dependencies created by `pkginfos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels", "lists")
load(":bazel_repo_names.bzl", "bazel_repo_names")
load(":bzl_selects.bzl", "bzl_selects")
load(":pkginfo_dependencies.bzl", "pkginfo_dependencies")
load(":pkginfo_targets.bzl", "pkginfo_targets")

# This value is used to group Bazel select conditions
_target_dep_kind = "_target_dep"

def _src_type_for_target(target):
    # Check Objc first. It will have a clang_src_info and an objc_src_info.
    if target.swift_src_info:
        return src_types.swift
    elif target.objc_src_info:
        return src_types.objc
    elif target.clang_src_info:
        return src_types.clang
    return src_types.unknown

def _modulemap_label_for_target(repo_name, target):
    return bazel_labels.new(
        name = pkginfo_targets.modulemap_label_name(target.label.name),
        repository_name = repo_name,
        package = target.label.package,
    )

def _labels_for_target(repo_name, target):
    labels = [
        bazel_labels.new(
            name = target.label.name,
            repository_name = repo_name,
            package = target.label.package,
        ),
    ]

    src_type = _src_type_for_target(target)
    if src_type == src_types.objc:
        # If the dep is an objc, return the real Objective-C target, not the Swift
        # module alias. This is part of a workaround for Objective-C modules not
        # being able to `@import` modules from other Objective-C modules.
        # See `swiftpkg_build_files.bzl` for more information.
        labels.append(_modulemap_label_for_target(repo_name, target))

    elif (src_type == src_types.swift and
          target.swift_src_info.has_objc_directive):
        # If an Objc module wants to @import a Swift module, it will need the
        # modulemap target.
        labels.append(_modulemap_label_for_target(repo_name, target))

    return labels

def _resolve_by_name(pkg_ctx, name):
    repo_name = bazel_repo_names.normalize(pkg_ctx.repo_name)

    # By name resolution logic:
    # 1. Check for target in this package.
    # 2. Check for product in this package.
    # 3. Check for a package with the same name as a dependent package.
    #
    # NOTE: This is different from what the SPM code seems to have coded.
    # However, if we do not check for a local target first, we can end up with
    # a circular dependency error in Bazel in the nimble_example.

    target = lists.find(pkg_ctx.pkg_info.targets, lambda t: t.name == name)
    if target != None:
        return _labels_for_target(repo_name, target)

    product = lists.find(pkg_ctx.pkg_info.products, lambda p: p.name == name)
    if product != None:
        return [
            bazel_labels.new(
                name = product.name,
                repository_name = repo_name,
                package = "",
            ),
        ]

    normalized_name = pkginfo_dependencies.normalize_name(name)

    ext_dep = lists.find(
        pkg_ctx.pkg_info.dependencies,
        lambda d: d.name == normalized_name,
    )
    if ext_dep != None:
        return [bazel_labels.new(
            name,
            repository_name = bazel_repo_names.from_identity(ext_dep.identity),
            package = "",
        )]
    fail("""\
Unable to resolve byName reference {name} in {repo_name}. For more information \
and to learn how to resolve the issue, please read \
https://github.com/cgrindel/rules_swift_package_manager/blob/main/docs/faq.md#how-do-i-handle-the-error-unable-to-resolve-byname-reference-xxx-in-swiftpkg_yyy.\
""".format(
        name = name,
        repo_name = repo_name,
    ))

def make_pkginfo_target_deps(bazel_labels):
    def _bzl_select_list(pkg_ctx, target_dep):
        """Return the Bazel labels associated with a target dependency.

        A module will resolve to a single label. A product can resolve to one
        or more labels.

        Args:
            pkg_ctx: A `struct` as returned by `pkg_ctxs.new`.
            target_dep: A `struct` as returned by
                `pkginfos.new_target_dependency`.

        Returns:
            A `list` of `struct` values as returned by `bzl_selects.new`
            representing the labels for the target dependency.
        """
        if target_dep.by_name:
            condition = target_dep.by_name.condition
            labels = _resolve_by_name(pkg_ctx, target_dep.by_name.name)

        elif target_dep.target:
            condition = target_dep.target.condition
            target = lists.find(
                pkg_ctx.pkg_info.targets,
                lambda t: t.name == target_dep.target.target_name,
            )
            if target == None:
                fail("""\
Unable to resolve target reference target dependency for {module_name}.\
""".format(module_name = target_dep.target.target_name))
            labels = _labels_for_target(pkg_ctx.repo_name, target)

        elif target_dep.product:
            condition = target_dep.product.condition
            prod_ref = target_dep.product
            repository_name = None
            if prod_ref.dep_name == pkg_ctx.pkg_info.name:
                repository_name = pkg_ctx.repo_name
            else:
                dep = pkginfo_dependencies.get_by_name(
                    pkg_ctx.pkg_info.dependencies,
                    prod_ref.dep_name,
                )
                if dep:
                    repository_name = bazel_repo_names.from_identity(dep.identity)
            if not repository_name:
                fail("""\
Did not find external dependency with product name {prod_name} and package \
name {pkg_name}.\
""".format(
                    pkg_name = prod_ref.dep_name,
                    prod_name = prod_ref.product_name,
                ))

            labels = [
                bazel_labels.new(
                    name = prod_ref.product_name,
                    repository_name = repository_name,
                    package = "",
                ),
            ]

        else:
            fail("""\
Unrecognized target dependency while generating a Bazel dependency label: {}.\
""".format(target_dep))

        return bzl_selects.new_from_target_dependency_condition(
            kind = _target_dep_kind,
            labels = [bazel_labels.normalize(label) for label in labels],
            condition = condition,
        )

    return struct(
        bzl_select_list = _bzl_select_list,
        target_dep_kind = _target_dep_kind,
        labels_for_target = _labels_for_target,
    )

pkginfo_target_deps = make_pkginfo_target_deps(
    bazel_labels = bazel_labels,
)

src_types = struct(
    unknown = "unknown",
    swift = "swift",
    clang = "clang",
    objc = "objc",
    binary = "binary",
    all_values = [
        "unknown",
        "swift",
        "clang",
        "objc",
        "binary",
    ],
)
