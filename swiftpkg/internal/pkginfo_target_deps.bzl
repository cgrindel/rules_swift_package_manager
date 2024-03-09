"""Module for generating data from target dependencies created by `pkginfos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels", "lists")
load(":bazel_repo_names.bzl", "bazel_repo_names")
load(":bzl_selects.bzl", "bzl_selects")
load(":deps_indexes.bzl", "deps_indexes", "src_types")
load(":pkginfo_dependencies.bzl", "pkginfo_dependencies")
load(":pkginfo_targets.bzl", "pkginfo_targets")

# This value is used to group Bazel select conditions
_target_dep_kind = "_target_dep"

def _src_type_for_target(target):
    if target.swift_src_info:
        return src_types.swift
    elif target.clang_src_info:
        return src_types.clang
    elif target.objc_src_info:
        return src_types.objc
    fail("Unknown source type for target {}.".format(target.name))

def _modulemap_label_for_target(repo_name, target):
    # return bazel_labels.new(
    #     name = pkginfo_targets.modulemap_label_name(target.label.name),
    #     repository_name = target.label.repository_name,
    #     package = target.label.package,
    # )
    # return ":{}".format(pkginfo_targets.modulemap_label_name(target.label.name))
    return bazel_labels.new(
        name = pkginfo_targets.modulemap_label_name(target.label.name),
        repository_name = repo_name,
        package = target.label.package,
    )

def _labels_for_target(repo_name, target, depender_target):
    # labels = [target.label]
    labels = [
        bazel_labels.new(
            name = target.label.name,
            repository_name = repo_name,
            package = target.label.package,
        ),
    ]

    src_type = _src_type_for_target(target)
    depender_src_type = _src_type_for_target(depender_target)
    if src_type == src_types.objc:
        # If the dep is an objc, return the real Objective-C target, not the Swift
        # module alias. This is part of a workaround for Objective-C modules not
        # being able to `@import` modules from other Objective-C modules.
        # See `swiftpkg_build_files.bzl` for more information.
        labels.append(_modulemap_label_for_target(repo_name, target))

    elif (depender_src_type == src_types.objc and
          src_type == src_types.swift and
          target.swift_src_info.has_objc_directive):
        # If an Objc module wants to @import a Swift module, it will need the
        # modulemap target.
        labels.append(_modulemap_label_for_target(repo_name, target))

    return labels

def _resolve_by_name(pkg_ctx, name, depender_target):
    repo_name = bazel_repo_names.normalize(pkg_ctx.repo_name)

    # Per the SPM code for >=5.2, look for a product in the same
    # package, else a target in the same package, else product in a
    # package with the same name. Otherwise, fail.
    product = deps_indexes.get_product(
        deps_index = pkg_ctx.deps_index_ctx.deps_index,
        identity = repo_name,
        name = name,
    )
    if product != None:
        return [product.label]

    target = lists.find(pkg_ctx.pkg_info.targets, lambda t: t.name == name)
    if target != None:
        return _labels_for_target(repo_name, target, depender_target)

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
    fail("Unable to resolve byName reference {name} in {repo_name}.".format(
        name = name,
        repo_name = repo_name,
    ))

def make_pkginfo_target_deps(bazel_labels):
    def _bzl_select_list(pkg_ctx, target_dep, depender_target):
        """Return the Bazel labels associated with a target dependency.

        A module will resolve to a single label. A product can resolve to one
        or more labels.

        Args:
            pkg_ctx: A `struct` as returned by `pkg_ctxs.new`.
            target_dep: A `struct` as returned by
                `pkginfos.new_target_dependency`.
            depender_target: The target that depends on the dependency as a
                `struct` (`pkginfos.new_target()`).

        Returns:
            A `list` of `struct` values as returned by `bzl_selects.new`
            representing the labels for the target dependency.
        """

        # # Find the depender module
        # depender_module = deps_indexes.resolve_module_with_ctx(
        #     pkg_ctx.deps_index_ctx,
        #     depender_module_name,
        # )
        # if depender_module == None:
        #     fail("Unable to find depender module named {}.".format(depender_module_name))

        if target_dep.by_name:
            condition = target_dep.by_name.condition
            labels = _resolve_by_name(pkg_ctx, target_dep.by_name.name, depender_target)

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
            labels = _labels_for_target(target, depender_target)

        elif target_dep.product:
            condition = target_dep.product.condition

            # TODO(chuck): Create the label directly from the product ref?
            prod_ref = target_dep.product
            dep = pkginfo_dependencies.get_by_name(
                pkg_ctx.pkg_info.dependencies,
                prod_ref.dep_name,
            )
            if dep == None:
                fail("""\
Did not find external dependency with name/identity {}.\
""".format(prod_ref.dep_name))

            product = deps_indexes.get_product(
                deps_index = pkg_ctx.deps_index_ctx.deps_index,
                identity = dep.identity,
                name = prod_ref.product_name,
            )
            if product == None:
                fail("""\
Unable to resolve product reference target dependency for product {prod_name} provided by {dep_name}.
""".format(
                    prod_name = prod_ref.product_name,
                    dep_name = prod_ref.dep_name,
                ))
            labels = [product.label]

        else:
            fail("""\
Unrecognized target dependency while generating a Bazel dependency label.\
""")

        if product:
            labels = [product.label]
        elif module:
            labels = (
                deps_indexes.labels_for_module(module)
            )
        else:
            labels = []

        def _custom_normalize(label):
            # Do not normalize the relative labels.
            if type(label) == "string" and label.startswith(":"):
                return label
            return bazel_labels.normalize(label)

        return bzl_selects.new_from_target_dependency_condition(
            kind = _target_dep_kind,
            labels = [_custom_normalize(label) for label in labels],
            condition = condition,
        )

    return struct(
        bzl_select_list = _bzl_select_list,
        target_dep_kind = _target_dep_kind,
    )

pkginfo_target_deps = make_pkginfo_target_deps(
    bazel_labels = bazel_labels,
)
