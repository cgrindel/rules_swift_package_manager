"""Module for generating data from target dependencies created by `pkginfos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")
load(":bazel_repo_names.bzl", "bazel_repo_names")
load(":module_indexes.bzl", "module_indexes")
load(":pkginfo_ext_deps.bzl", "pkginfo_ext_deps")

def make_pkginfo_target_deps(bazel_labels):
    def _bazel_label(pkg_info, module_index, target_dep, repo_name = None):
        """Create a Bazel label string from a target dependency.

        Args:
            pkg_info: A `struct` as returned by `pkginfos.new`.
            module_index: A `struct` as returned by
                `module_indexes.new_from_json`.
            target_dep: A `struct` as returned by
                `pkginfos.new_target_dependency`.
            repo_name: The name of the repository as a `string`. This must be
                provided if the module is being used outside of a BUILD thread.

        Returns:
            A `string` representing the label for the target dependency.
        """

        if target_dep.by_name:
            # TODO(chuck): Move this outside of this function so that we don't recreate it.
            restrict_to_repo_names = [
                pkginfo_ext_deps.repo_name(dep)
                for dep in pkg_info.dependencies
            ]
            # if repo_name != None:
            #     restrict_to_repo_names.append(repo_name)

            label = module_indexes.find(
                module_index,
                module_name = target_dep.by_name.target_name,
                preferred_repo_name = repo_name,
                restrict_to_repo_names = restrict_to_repo_names,
            )
            if label == None:
                fail("""\
Unable to resolve by_name target dependency for {module_name}.
""".format(module_name = target_dep.by_name.target_name))

        elif target_dep.product:
            prod_ref = target_dep.product
            ext_dep = pkginfo_ext_deps.find_by_identity(
                pkg_info.dependencies,
                prod_ref.dep_identity,
            )
            restrict_to_repo_names = [bazel_repo_names.from_url(ext_dep.url)]
            label = module_indexes.find(
                module_index,
                module_name = prod_ref.product_name,
                restrict_to_repo_names = restrict_to_repo_names,
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
