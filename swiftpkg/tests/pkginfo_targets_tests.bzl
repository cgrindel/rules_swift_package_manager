"""Tests for `pkginfo_targets`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "make_bazel_labels", "make_stub_workspace_name_resolvers")
load("//swiftpkg/internal:package_infos.bzl", "module_types", "package_infos", "target_types")
load("//swiftpkg/internal:pkginfo_target_deps.bzl", "make_pkginfo_target_deps")
load("//swiftpkg/internal:pkginfo_targets.bzl", "pkginfo_targets")

workspace_name_resolovers = make_stub_workspace_name_resolvers()
bazel_labels = make_bazel_labels(workspace_name_resolovers)
pkginfo_target_deps = make_pkginfo_target_deps(bazel_labels)

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

def _bazel_label_test(ctx):
    env = unittest.begin(ctx)

    unittest.fail(env, "IMPLEMENT ME!")

    return unittest.end(env)

bazel_label_test = unittest.make(_bazel_label_test)

def pkginfo_targets_test_suite():
    return unittest.suite(
        "pkginfo_targets_tests",
        get_test,
        bazel_label_test,
    )
