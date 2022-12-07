"""Tests for `pkginfo_targets`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "make_bazel_labels", "make_stub_workspace_name_resolvers")
load("//swiftpkg/internal:package_infos.bzl", "module_types", "package_infos", "target_types")
load("//swiftpkg/internal:pkginfo_target_deps.bzl", "make_pkginfo_target_deps")
load("//swiftpkg/internal:pkginfo_targets.bzl", "pkginfo_targets")

workspace_name_resolovers = make_stub_workspace_name_resolvers()
bazel_labels = make_bazel_labels(workspace_name_resolovers)
pkginfo_target_deps = make_pkginfo_target_deps(bazel_labels)
# pkginfo_targets = make_pkginfo_targets(pkginfo_target_deps)

# _external_dep = package_infos.new_dependency(
#     identity = "example-swift-package",
#     type = "sourceControl",
#     url = "https://github.com/example/swift-package",
#     requirement = package_infos.new_dependency_requirement(
#         ranges = [
#             package_infos.new_version_range("1.2.0", "2.0.0"),
#         ],
#     ),
# )
# _by_name = package_infos.new_target_reference("Foo")
# _product_ref = package_infos.new_product_reference(
#     product_name = "Chicken",
#     dep_identity = _external_dep.identity,
# )

# _pkg_info = package_infos.new(
#     name = "MyPackage",
#     path = "/path/to/package",
#     dependencies = [_external_dep],
# )

# _foo_target = package_infos.new_target(
#     name = "Foo",
#     type = target_types.library,
#     c99name = "Foo",
#     module_type = module_types.swift,
#     path = "Sources/Foo",
#     sources = ["Chicken.swift", "Chicken+Extensions.swift"],
#     dependencies = [
#         package_infos.new_target_dependency(by_name = _by_name),
#         package_infos.new_target_dependency(product = _product_ref),
#     ],
# )

# def _srcs_test(ctx):
#     env = unittest.begin(ctx)

#     actual = pkginfo_targets.srcs(_foo_target)
#     expected = [
#         "Sources/Foo/Chicken.swift",
#         "Sources/Foo/Chicken+Extensions.swift",
#     ]
#     asserts.equals(env, expected, actual)

#     return unittest.end(env)

# srcs_test = unittest.make(_srcs_test)

# def _deps_test(ctx):
#     env = unittest.begin(ctx)

#     actual = pkginfo_targets.deps(_pkg_info, _foo_target)
#     expected = [
#         "@//:Foo",
#         "@example_swift_package//:Chicken",
#     ]
#     asserts.equals(env, expected, actual)

#     return unittest.end(env)

# deps_test = unittest.make(_deps_test)

def _get_test(ctx):
    env = unittest.begin(ctx)

    bar_target = package_infos.new_target(
        name = "Bar",
        type = target_types.library,
        c99name = "Bar",
        module_type = module_types.swift,
        path = "/path/to/bar",
        sources = [],
        dependencies = [],
    )
    foo_target = package_infos.new_target(
        name = "Foo",
        type = target_types.library,
        c99name = "Foo",
        module_type = module_types.swift,
        path = "/path/to/foo",
        sources = [],
        dependencies = [],
    )
    targets = [foo_target, bar_target]

    actual = pkginfo_targets.get(targets, "does_not_exist", fail_if_not_found = False)
    asserts.equals(env, None, actual)

    actual = pkginfo_targets.get(targets, bar_target.name, fail_if_not_found = False)
    asserts.equals(env, bar_target, actual)

    actual = pkginfo_targets.get(targets, foo_target.name, fail_if_not_found = False)
    asserts.equals(env, foo_target, actual)

    return unittest.end(env)

get_test = unittest.make(_get_test)

def pkginfo_targets_test_suite():
    return unittest.suite(
        "pkginfo_targets_tests",
        # srcs_test,
        # deps_test,
        get_test,
    )
