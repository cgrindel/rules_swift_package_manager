"""Tests for `pkginfo_targets`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "make_bazel_labels", "make_stub_workspace_name_resolvers")
load("//swiftpkg/internal:package_infos.bzl", "module_types", "package_infos", "target_types")
load("//swiftpkg/internal:pkginfo_targets.bzl", "make_pkginfo_targets")

workspace_name_resolovers = make_stub_workspace_name_resolvers()
bazel_labels = make_bazel_labels(workspace_name_resolovers)
pkginfo_targets = make_pkginfo_targets(bazel_labels)

_bar_target = package_infos.new_target(
    name = "Bar",
    type = target_types.library,
    c99name = "Bar",
    module_type = module_types.swift,
    path = "Sources/Bar",
    sources = [],
    dependencies = [],
)
_foo_target = package_infos.new_target(
    name = "Foo",
    type = target_types.library,
    c99name = "Foo",
    module_type = module_types.swift,
    path = "Sources/Foo",
    sources = [],
    dependencies = [],
)

def _get_test(ctx):
    env = unittest.begin(ctx)

    targets = [_foo_target, _bar_target]

    actual = pkginfo_targets.get(targets, "does_not_exist", fail_if_not_found = False)
    asserts.equals(env, None, actual)

    actual = pkginfo_targets.get(targets, _bar_target.name, fail_if_not_found = False)
    asserts.equals(env, _bar_target, actual)

    actual = pkginfo_targets.get(targets, _foo_target.name, fail_if_not_found = False)
    asserts.equals(env, _foo_target, actual)

    return unittest.end(env)

get_test = unittest.make(_get_test)

def _bazel_label_test(ctx):
    env = unittest.begin(ctx)

    actual = pkginfo_targets.bazel_label(_bar_target)
    expected = "@//Sources/Bar:Bar"
    asserts.equals(env, expected, actual)

    actual = pkginfo_targets.bazel_label(_foo_target)
    expected = "@//Sources/Foo:Foo"
    asserts.equals(env, expected, actual)

    return unittest.end(env)

bazel_label_test = unittest.make(_bazel_label_test)

def pkginfo_targets_test_suite():
    return unittest.suite(
        "pkginfo_targets_tests",
        get_test,
        bazel_label_test,
    )
