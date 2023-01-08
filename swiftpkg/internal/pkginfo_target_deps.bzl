"""Module for generating data from target dependencies created by `pkginfos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels", "lists")
load(":deps_indexes.bzl", "deps_indexes")

def make_pkginfo_target_deps(bazel_labels):
    def _bazel_label_strs(pkg_ctx, target_dep):
        """Return the Bazel labels associated with a target dependency.

        A module will resolve to a single label. A product can resolve to one
        or more labels.

        Args:
            pkg_ctx: A `struct` as returned by `pkg_ctxs.new`.
            target_dep: A `struct` as returned by
                `pkginfos.new_target_dependency`.

        Returns:
            A `list` of `string` values representing the labels for the target
            dependency.
        """

        if target_dep.by_name:
            labels = lists.compact([
                deps_indexes.resolve_module_label_with_ctx(
                    pkg_ctx.deps_index_ctx,
                    target_dep.by_name.name,
                ),
            ])
            if len(labels) == 0:
                fail("""\
Unable to resolve by_name target dependency for {module_name}.
""".format(module_name = target_dep.by_name.name))

        elif target_dep.target:
            labels = lists.compact([
                deps_indexes.resolve_module_label_with_ctx(
                    pkg_ctx.deps_index_ctx,
                    target_dep.target.target_name,
                ),
            ])
            if len(labels) == 0:
                fail("""\
Unable to resolve target reference target dependency for {module_name}.
""".format(module_name = target_dep.target.target_name))

        elif target_dep.product:
            prod_ref = target_dep.product
            labels = deps_indexes.resolve_product_labels(
                deps_index = pkg_ctx.deps_index_ctx.deps_index,
                identity = prod_ref.dep_identity,
                name = prod_ref.product_name,
            )
            if len(labels) == 0:
                fail("""\
Unable to resolve product reference target dependency for product {prod_name} provided by {dep_id}.
""".format(
                    prod_name = prod_ref.product_name,
                    dep_id = prod_ref.dep_identity,
                ))

        else:
            fail("""\
Unrecognized target dependency while generating a Bazel dependency label.\
""")

        return [
            bazel_labels.normalize(label)
            for label in labels
        ]

    return struct(
        bazel_label_strs = _bazel_label_strs,
    )

pkginfo_target_deps = make_pkginfo_target_deps(
    bazel_labels = bazel_labels,
)
