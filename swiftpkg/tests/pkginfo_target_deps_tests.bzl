"""Tests for `pkginfo_test_deps`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "make_bazel_labels", "make_stub_workspace_name_resolvers")
load("//swiftpkg/internal:pkg_ctxs.bzl", "pkg_ctxs")
load("//swiftpkg/internal:pkginfo_target_deps.bzl", "make_pkginfo_target_deps")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")

_repo_name = "@example_cool_repo"

workspace_name_resolovers = make_stub_workspace_name_resolvers(
    repo_name = _repo_name,
)
bazel_labels = make_bazel_labels(workspace_name_resolovers)
pkginfo_target_deps = make_pkginfo_target_deps(
    bazel_labels = bazel_labels,
)

_external_dep = pkginfos.new_dependency(
    identity = "example-swift-package",
    type = "sourceControl",
    url = "https://github.com/example/swift-package",
    requirement = pkginfos.new_dependency_requirement(
        ranges = [
            pkginfos.new_version_range("1.2.0", "2.0.0"),
        ],
    ),
)
_by_name = pkginfos.new_by_name_reference("Foo")
_product_ref = pkginfos.new_product_reference(
    product_name = "AwesomePackage",
    dep_identity = _external_dep.identity,
)

_pkg_info = pkginfos.new(
    name = "MyPackage",
    path = "/path/to/package",
    dependencies = [_external_dep],
    targets = [
        pkginfos.new_target(
            name = "Bar",
            type = "regular",
            c99name = "Bar",
            module_type = "SwiftTarget",
            path = "Source/Bar",
            sources = [
                "Bar.swift",
            ],
            dependencies = [],
        ),
    ],
)

_module_index_json = """\
{
  "AwesomePackage": [
    "@swiftpkg_example_swift_package//:AwesomePackage"
  ],
  "Foo": [
    "@swiftpkg_example_swift_package//:Source/Foo"
  ]
}
"""

_pkg_ctx = pkg_ctxs.new(
    pkg_info = _pkg_info,
    repo_name = _repo_name,
    module_index_json = _module_index_json,
)

def _bazel_label_by_name_test(ctx):
    env = unittest.begin(ctx)

    target_dep = pkginfos.new_target_dependency(by_name = _by_name)

    actual = pkginfo_target_deps.bazel_label(_pkg_ctx, target_dep)
    expected = bazel_labels.normalize("@swiftpkg_example_swift_package//:Source/Foo")
    asserts.equals(env, expected, actual)

    return unittest.end(env)

bazel_label_by_name_test = unittest.make(_bazel_label_by_name_test)

def _bazel_label_product_ref_test(ctx):
    env = unittest.begin(ctx)

    target_dep = pkginfos.new_target_dependency(product = _product_ref)
    actual = pkginfo_target_deps.bazel_label(_pkg_ctx, target_dep)
    expected = bazel_labels.normalize(
        bazel_labels.new(
            repository_name = "swiftpkg_example_swift_package",
            package = "",
            name = _product_ref.product_name,
        ),
    )
    asserts.equals(env, expected, actual)

    return unittest.end(env)

bazel_label_product_ref_test = unittest.make(_bazel_label_product_ref_test)

def pkginfo_target_deps_test_suite():
    return unittest.suite(
        "pkginfo_target_deps_tests",
        bazel_label_by_name_test,
        bazel_label_product_ref_test,
    )
