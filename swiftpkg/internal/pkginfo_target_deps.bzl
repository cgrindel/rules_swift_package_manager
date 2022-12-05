"""Module for generating data from target dependencies created by `package_infos`."""

load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "bazel_labels")

def make_pkginfo_target_deps(bazel_labels = bazel_labels):
    def _bazel_label(pkg_info, target_dep):
        if target_dep.by_name:
            return bazel_labels.normalize(target_dep.by_name.target_name)
        elif target_dep.product:
            # TODO(chuck): IMPLEMENT ME!
            # prod_ref = target_dep.product
            # ext_dep = pkginfo_deps.find_by_identity(
            #     pkg_info.dependencies,
            #     prod_ref.identity,
            # )
            # repo_name = bazel_repo_names.from_url(ext_dep.url)
            # return bazel_labels.create(
            #     repository_name = "@{}".format(repo_name),
            #     package = "",
            #     name = prod_ref.product_name,
            # )
            return None
        else:
            fail("""\
Unrecognized target dependency while generating a Bazel dependency label.\
""")

    return struct(
        bazel_label = _bazel_label,
    )

pkginfo_target_deps = make_pkginfo_target_deps(bazel_labels = bazel_labels)
