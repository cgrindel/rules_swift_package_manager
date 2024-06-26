"""Tests for `pkginfo_test_deps`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "make_bazel_labels", "make_stub_workspace_name_resolvers")
load("//config_settings/spm/platform:platforms.bzl", spm_platforms = "platforms")
load("//swiftpkg/internal:bzl_selects.bzl", "bzl_selects")
load("//swiftpkg/internal:pkg_ctxs.bzl", "pkg_ctxs")
load("//swiftpkg/internal:pkginfo_target_deps.bzl", "make_pkginfo_target_deps")
load("//swiftpkg/internal:pkginfos.bzl", "library_type_kinds", "pkginfos")

_repo_name = "@swiftpkg_mypackage"

workspace_name_resolovers = make_stub_workspace_name_resolvers(
    repo_name = _repo_name,
)
bazel_labels = make_bazel_labels(workspace_name_resolovers)
pkginfo_target_deps = make_pkginfo_target_deps(
    bazel_labels = bazel_labels,
)

_target_dep_condition = pkginfos.new_target_dependency_condition(
    platforms = ["ios", "tvos"],
)

# AwesomePackage (external dependency)

_external_dep = pkginfos.new_dependency(
    identity = "awesomepackage-identity",
    name = "AwesomePackage",
    file_system = pkginfos.new_file_system(
        path = "/path/to/AwesomePackage",
    ),
)

# External product references by name MUST match the package name.
_external_product_by_name = pkginfos.new_by_name_reference("AwesomePackage")

# Purposefully, referencing a product that does not match the name of the
# package. We want to ensure that implementation is not falling into the byName
# code path.
_external_product_ref = pkginfos.new_product_reference(
    product_name = "AwesomeProduct",
    dep_name = _external_dep.name,
)
_external_product_ref_with_condition = pkginfos.new_product_reference(
    product_name = "AwesomeProduct",
    dep_name = _external_dep.name,
    condition = _target_dep_condition,
)

# MyPackage

_pkg_name = "MyPackage"

_foo_target = pkginfos.new_target(
    name = "Foo",
    type = "regular",
    c99name = "Foo",
    module_type = "SwiftTarget",
    path = "Source/Foo",
    sources = [
        "Foo.swift",
    ],
    dependencies = [],
    repo_name = _repo_name,
)
_bar_target = pkginfos.new_target(
    name = "Bar",
    type = "regular",
    c99name = "Bar",
    module_type = "SwiftTarget",
    path = "Source/Bar",
    sources = [
        "Bar.swift",
    ],
    # Technically, this target has as dependency on Foo in these examples.
    # However, we are testing different references to Foo from Bar. So, we
    # don't specify any references here to minimize the confusion.
    dependencies = [],
    repo_name = _repo_name,
)

_bar_product = pkginfos.new_product(
    name = "Bar",
    type = pkginfos.new_product_type(
        library = pkginfos.new_library_type(library_type_kinds.automatic),
    ),
    targets = [_bar_target.name],
)

_internal_target_ref = pkginfos.new_target_reference(
    target_name = _foo_target.name,
)
_internal_target_by_name_with_condition = pkginfos.new_by_name_reference(
    _foo_target.name,
    condition = _target_dep_condition,
)
_internal_target_ref_with_condition = pkginfos.new_target_reference(
    target_name = _foo_target.name,
    condition = _target_dep_condition,
)

_internal_product_ref = pkginfos.new_product_reference(
    product_name = _bar_product.name,
    dep_name = _pkg_name,
)
_expected_platform_conditions = [
    spm_platforms.label(p)
    for p in _target_dep_condition.platforms
]

_pkg_info = pkginfos.new(
    name = "MyPackage",
    path = "/path/to/package",
    dependencies = [_external_dep],
    targets = [_foo_target, _bar_target],
    products = [_bar_product],
)

_pkg_ctx = pkg_ctxs.new(
    pkg_info = _pkg_info,
    repo_name = _repo_name,
)

def _bzl_select_list_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "external product by name, no condition",
            td = pkginfos.new_target_dependency(by_name = _external_product_by_name),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_awesomepackage_identity//:AwesomePackage",
                        ),
                    ],
                ),
            ],
        ),
        struct(
            msg = "external product ref, no condition",
            td = pkginfos.new_target_dependency(product = _external_product_ref),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_awesomepackage_identity//:AwesomeProduct",
                        ),
                    ],
                ),
            ],
        ),
        struct(
            msg = "external product ref, with condition",
            td = pkginfos.new_target_dependency(product = _external_product_ref_with_condition),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_awesomepackage_identity//:AwesomeProduct",
                        ),
                    ],
                    condition = c,
                )
                for c in _expected_platform_conditions
            ],
        ),
        struct(
            msg = "internal target ref, no condition",
            td = pkginfos.new_target_dependency(target = _internal_target_ref),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_mypackage//:Foo.rspm",
                        ),
                    ],
                ),
            ],
        ),
        struct(
            msg = "internal target by name, with condition",
            td = pkginfos.new_target_dependency(by_name = _internal_target_by_name_with_condition),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_mypackage//:Foo.rspm",
                        ),
                    ],
                    condition = c,
                )
                for c in _expected_platform_conditions
            ],
        ),
        struct(
            msg = "internal target ref, with condition",
            td = pkginfos.new_target_dependency(target = _internal_target_ref_with_condition),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_mypackage//:Foo.rspm",
                        ),
                    ],
                    condition = c,
                )
                for c in _expected_platform_conditions
            ],
        ),
        struct(
            msg = "internal product ref, no condition",
            td = pkginfos.new_target_dependency(product = _internal_product_ref),
            exp = [
                bzl_selects.new(
                    kind = pkginfo_target_deps.target_dep_kind,
                    value = [
                        bazel_labels.normalize(
                            "@swiftpkg_mypackage//:Bar",
                        ),
                    ],
                ),
            ],
        ),
    ]
    for t in tests:
        actual = pkginfo_target_deps.bzl_select_list(_pkg_ctx, t.td)
        asserts.equals(env, t.exp, actual, t.msg)

    return unittest.end(env)

bzl_select_list_test = unittest.make(_bzl_select_list_test)

def pkginfo_target_deps_test_suite():
    return unittest.suite(
        "pkginfo_target_deps_tests",
        bzl_select_list_test,
    )
