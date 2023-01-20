"""Module for generating data from target dependencies created by `pkginfos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels", "lists")
load(":deps_indexes.bzl", "deps_indexes")
load(":pkginfo_dependencies.bzl", "pkginfo_dependencies")

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
                # Seeing Package.swift files with byName dependencies that
                # cannot be resolved (i.e., they do not exist).
                # Example `protoc-gen-swift` in
                # `https://github.com/grpc/grpc-swift.git`.
                # Printing warnings is discouraged. So, just keep moving
                # print("""\
                # Unable to resolve by_name target dependency for {module_name}.\
                # """.format(module_name = target_dep.by_name.name))
                pass

        elif target_dep.target:
            labels = lists.compact([
                deps_indexes.resolve_module_label_with_ctx(
                    pkg_ctx.deps_index_ctx,
                    target_dep.target.target_name,
                ),
            ])
            if len(labels) == 0:
                fail("""\
Unable to resolve target reference target dependency for {module_name}.\
""".format(module_name = target_dep.target.target_name))

        elif target_dep.product:
            prod_ref = target_dep.product
            dep = pkginfo_dependencies.get_by_name(
                pkg_ctx.pkg_info.dependencies,
                prod_ref.dep_name,
            )
            if dep == None:
                fail("""\
Did not find external dependency with name/identity {}.\
""".format(prod_ref.dep_name))

            # DEBUG BEGIN
            print("*** CHUCK dep: ", dep)
            print("*** CHUCK prod_ref.product_name: ", prod_ref.product_name)

            # DEBUG END
            labels = deps_indexes.resolve_product_labels(
                deps_index = pkg_ctx.deps_index_ctx.deps_index,
                identity = dep.identity,
                name = prod_ref.product_name,
            )
            if len(labels) == 0:
                fail("""\
Unable to resolve product reference target dependency for product {prod_name} provided by {dep_name}.
""".format(
                    prod_name = prod_ref.product_name,
                    dep_name = prod_ref.dep_name,
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
