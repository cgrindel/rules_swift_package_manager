"""Module for generating data from target dependencies created by `pkginfos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")
load(":bazel_repo_names.bzl", "bazel_repo_names")
load(":module_indexes.bzl", "module_indexes")
load(":pkginfo_ext_deps.bzl", "pkginfo_ext_deps")

def make_pkginfo_target_deps(bazel_labels):
    def _bazel_label(pkg_ctx, target_dep):
        """Create a Bazel label string from a target dependency.

        Args:
            pkg_ctx: A `struct` as returned by `pkg_ctxs.new`.
            target_dep: A `struct` as returned by
                `pkginfos.new_target_dependency`.

        Returns:
            A `string` representing the label for the target dependency.
        """

        if target_dep.by_name:
            label = module_indexes.find_with_ctx(
                pkg_ctx.module_index_ctx,
                target_dep.by_name.name,
            )
            if label == None:
                fail("""\
Unable to resolve by_name target dependency for {module_name}.
""".format(module_name = target_dep.by_name.target_name))

        elif target_dep.target:
            label = module_indexes.find_with_ctx(
                pkg_ctx.module_index_ctx,
                target_dep.target.target_name,
            )
            if label == None:
                fail("""\
Unable to resolve target reference target dependency for {module_name}.
""".format(module_name = target_dep.target.target_name))

        elif target_dep.product:
            prod_ref = target_dep.product
            ext_dep = pkginfo_ext_deps.find_by_identity(
                pkg_ctx.pkg_info.dependencies,
                prod_ref.dep_identity,
            )

            # Restrict the search to only the specified external dep
            label = module_indexes.find(
                module_index = pkg_ctx.module_index_ctx.module_index,
                module_name = prod_ref.product_name,
                restrict_to_repo_names = [
                    bazel_repo_names.from_url(ext_dep.url),
                ],
            )

            if label == None:
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
        return bazel_labels.normalize(label)

    return struct(
        bazel_label = _bazel_label,
    )

pkginfo_target_deps = make_pkginfo_target_deps(
    bazel_labels = bazel_labels,
)
