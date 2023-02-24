"""Tests for `pkginfo_test_deps`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "make_bazel_labels", "make_stub_workspace_name_resolvers")
load("//config_settings/spm/platform:platforms.bzl", spm_platforms = "platforms")
load("//swiftpkg/internal:bzl_selects.bzl", "bzl_selects")
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
    name = "ASwiftPackage",
    type = "sourceControl",
    url = "https://github.com/example/swift-package",
    requirement = pkginfos.new_dependency_requirement(
        ranges = [
            pkginfos.new_version_range("1.2.0", "2.0.0"),
        ],
    ),
)

# _target_by_name = pkginfos.new_by_name_reference("Foo")
_target_by_name = pkginfos.new_by_name_reference("Baz")
_product_by_name = pkginfos.new_by_name_reference("AwesomeProduct")
_product_ref = pkginfos.new_product_reference(
    product_name = "AwesomeProduct",
    dep_name = _external_dep.name,
)
_target_ref = pkginfos.new_target_reference(
    target_name = "Foo",
)

_target_dep_condition = pkginfos.new_target_dependency_condition(
    platforms = ["ios", "tvos"],
)
_by_name_with_condition = pkginfos.new_by_name_reference(
    "Foo",
    condition = _target_dep_condition,
)
_product_ref_with_condition = pkginfos.new_product_reference(
    product_name = "AwesomeProduct",
    dep_name = _external_dep.name,
    condition = _target_dep_condition,
)
_target_ref_with_condition = pkginfos.new_target_reference(
    target_name = "Foo",
    condition = _target_dep_condition,
)
_expected_platform_conditions = [
    spm_platforms.label(p)
    for p in _target_dep_condition.platforms
]

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

_deps_index_json = """\
{
  "modules": [
    {
      "name": "AwesomePackage",
      "c99name": "AwesomePackage",
      "src_type": "swift",
      "label": "@swiftpkg_example_swift_package//:AwesomePackage"
    },
    {
      "name": "Foo",
      "c99name": "Foo",
      "src_type": "swift",
      "label": "@swiftpkg_example_swift_package//:Source/Foo"
    },
    {
      "name": "Baz",
      "c99name": "Baz",
      "src_type": "swift",
      "label": "@swiftpkg_example_swift_package//:Source/Baz"
    },
    {
      "name": "MoreBaz",
      "c99name": "MoreBaz",
      "src_type": "swift",
      "label": "@swiftpkg_example_swift_package//:Source/MoreBaz"
    }
  ],
  "products": [
    {
      "identity": "example-swift-package",
      "name": "AwesomeProduct",
      "type": "library",
      "target_labels": [
        "@swiftpkg_example_swift_package//:AwesomePackage",
        "@swiftpkg_example_swift_package//:Source/Baz"
      ]
    },
    {
      "identity": "example-swift-package",
      "name": "Baz",
      "type": "library",
      "target_labels": [
        "@swiftpkg_example_swift_package//:Source/Baz",
        "@swiftpkg_example_swift_package//:Source/MoreBaz"
      ]
    }
  ]
}
"""

_pkg_ctx = pkg_ctxs.new(
    pkg_info = _pkg_info,
    repo_name = _repo_name,
    deps_index_json = _deps_index_json,
)

def _bzl_select_list_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "by name for target not the product with the same name, no condition",
            td = pkginfos.new_target_dependency(by_name = _target_by_name),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_example_swift_package//:Source/Baz",
                        ),
                    ],
                ),
            ],
        ),
        struct(
            msg = "by name for product, no condition",
            td = pkginfos.new_target_dependency(by_name = _product_by_name),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_example_swift_package//:AwesomePackage",
                        ),
                        bazel_labels.normalize(
                            "@swiftpkg_example_swift_package//:Source/Baz",
                        ),
                    ],
                ),
            ],
        ),
        struct(
            msg = "product ref, no condition",
            td = pkginfos.new_target_dependency(product = _product_ref),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_example_swift_package//:AwesomePackage",
                        ),
                        bazel_labels.normalize(
                            "@swiftpkg_example_swift_package//:Source/Baz",
                        ),
                    ],
                ),
            ],
        ),
        struct(
            msg = "target ref, no condition",
            td = pkginfos.new_target_dependency(target = _target_ref),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_example_swift_package//:Source/Foo",
                        ),
                    ],
                ),
            ],
        ),
        struct(
            msg = "by name, with condition",
            td = pkginfos.new_target_dependency(by_name = _by_name_with_condition),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_example_swift_package//:Source/Foo",
                        ),
                    ],
                    condition = c,
                )
                for c in _expected_platform_conditions
            ],
        ),
        struct(
            msg = "product ref, with condition",
            td = pkginfos.new_target_dependency(product = _product_ref_with_condition),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_example_swift_package//:AwesomePackage",
                        ),
                        bazel_labels.normalize(
                            "@swiftpkg_example_swift_package//:Source/Baz",
                        ),
                    ],
                    condition = c,
                )
                for c in _expected_platform_conditions
            ],
        ),
        struct(
            msg = "target ref, with condition",
            td = pkginfos.new_target_dependency(target = _target_ref_with_condition),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_example_swift_package//:Source/Foo",
                        ),
                    ],
                    condition = c,
                )
                for c in _expected_platform_conditions
            ],
        ),
    ]
    for t in tests:
        actual = pkginfo_target_deps.bzl_select_list(_pkg_ctx, t.td, "Foo")
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

bzl_select_list_test = unittest.make(_bzl_select_list_test)

def pkginfo_target_deps_test_suite():
    return unittest.suite(
        "pkginfo_target_deps_tests",
        bzl_select_list_test,
    )
