"""Tests for `pkginfo_targets`."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "make_bazel_labels", "make_stub_workspace_name_resolvers")
load("//swiftpkg/internal:pkginfo_targets.bzl", "make_pkginfo_targets")
load("//swiftpkg/internal:pkginfos.bzl", "module_types", "pkginfos", "target_types")

_repo_name = "@example_cool_repo"

workspace_name_resolovers = make_stub_workspace_name_resolvers(
    repo_name = _repo_name,
)
bazel_labels = make_bazel_labels(workspace_name_resolovers)
pkginfo_targets = make_pkginfo_targets(bazel_labels)

_bar_target = pkginfos.new_target(
    name = "Bar",
    type = target_types.library,
    c99name = "Bar",
    module_type = module_types.swift,
    path = "Sources/Bar",
    sources = ["Chicken.swift", "Smidgen/Hello.swift"],
    dependencies = [],
    repo_name = _repo_name,
)
_foo_target = pkginfos.new_target(
    name = "Foo",
    type = target_types.library,
    c99name = "Foo",
    module_type = module_types.swift,
    path = "Sources/Foo",
    sources = [],
    dependencies = [],
    repo_name = _repo_name,
)
_chocolate_target = pkginfos.new_target(
    name = "Chocolate",
    type = target_types.library,
    c99name = "Chocolate",
    module_type = module_types.swift,
    path = "Sources/Bar",
    sources = [],
    dependencies = [],
    repo_name = _repo_name,
)
_dot_path_target = pkginfos.new_target(
    name = "DotPath",
    type = target_types.library,
    c99name = "DotPath",
    module_type = module_types.swift,
    path = ".",
    sources = ["Chicken.swift", "Smidgen/Hello.swift"],
    dependencies = [],
    repo_name = _repo_name,
)
_simple_path_target = pkginfos.new_target(
    name = "simple_path",
    type = target_types.library,
    c99name = "simple_path",
    module_type = module_types.swift,
    path = "simple_path",
    sources = ["Simple.swift"],
    dependencies = [],
    repo_name = _repo_name,
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
    expected = bazel_labels.parse("@example_cool_repo//:Sources_Bar")
    asserts.equals(env, expected, actual)

    actual = pkginfo_targets.bazel_label(_foo_target, "@another_repo")
    expected = bazel_labels.parse("@another_repo//:Sources_Foo")
    asserts.equals(env, expected, actual)

    actual = pkginfo_targets.bazel_label(_chocolate_target)
    expected = bazel_labels.parse("@example_cool_repo//:Sources_Bar_Chocolate")
    asserts.equals(env, expected, actual)

    return unittest.end(env)

bazel_label_test = unittest.make(_bazel_label_test)

def _srcs_test(ctx):
    env = unittest.begin(ctx)

    actual = pkginfo_targets.srcs(_bar_target)
    expected = [
        "Sources/Bar/Chicken.swift",
        "Sources/Bar/Smidgen/Hello.swift",
    ]
    asserts.equals(env, expected, actual)

    actual = pkginfo_targets.srcs(_dot_path_target)
    expected = [
        "Chicken.swift",
        "Smidgen/Hello.swift",
    ]
    asserts.equals(env, expected, actual)

    return unittest.end(env)

srcs_test = unittest.make(_srcs_test)

def _bazel_label_name_test(ctx):
    env = unittest.begin(ctx)

    actual = pkginfo_targets.bazel_label_name(_bar_target)
    expected = "Sources_Bar"
    asserts.equals(env, expected, actual)

    actual = pkginfo_targets.bazel_label_name(_chocolate_target)
    expected = "Sources_Bar_Chocolate"
    asserts.equals(env, expected, actual)

    actual = pkginfo_targets.bazel_label_name(_dot_path_target)
    expected = "DotPath"
    asserts.equals(env, expected, actual)

    actual = pkginfo_targets.bazel_label_name(_simple_path_target)
    expected = "simple_path_simple_path"
    asserts.equals(env, expected, actual)

    return unittest.end(env)

bazel_label_name_test = unittest.make(_bazel_label_name_test)

def _join_path_test(ctx):
    env = unittest.begin(ctx)

    actual = pkginfo_targets.join_path(_bar_target, "foo")
    expected = paths.join(_bar_target.path, "foo")
    asserts.equals(env, expected, actual)

    actual = pkginfo_targets.join_path(_dot_path_target, "foo")
    expected = "foo"
    asserts.equals(env, expected, actual)

    return unittest.end(env)

join_path_test = unittest.make(_join_path_test)

def _modulemap_label_names_test(ctx):
    env = unittest.begin(ctx)

    asserts.false(env, pkginfo_targets.is_modulemap_label("Foo"))
    mm_label = pkginfo_targets.modulemap_label_name("Foo")
    asserts.true(env, pkginfo_targets.is_modulemap_label(mm_label))

    return unittest.end(env)

modulemap_label_names_test = unittest.make(_modulemap_label_names_test)

def pkginfo_targets_test_suite():
    return unittest.suite(
        "pkginfo_targets_tests",
        get_test,
        bazel_label_test,
        srcs_test,
        bazel_label_name_test,
        join_path_test,
    )
