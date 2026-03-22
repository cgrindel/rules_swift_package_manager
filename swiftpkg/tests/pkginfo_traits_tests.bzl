"""Tests for SPM trait support in `pkginfos` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")

# MARK: - Trait Parsing Tests

def _enabled_traits_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "default trait enables Foo",
            dump = {
                "traits": [
                    {"enabledTraits": ["Foo"], "name": "default"},
                    {"description": "The Foo trait", "name": "Foo"},
                    {"description": "The Bar trait", "name": "Bar"},
                ],
            },
            exp = ["Foo"],
        ),
        struct(
            msg = "no default trait yields empty set",
            dump = {
                "traits": [
                    {"description": "The Foo trait", "name": "Foo"},
                ],
            },
            exp = [],
        ),
        struct(
            msg = "default with empty enabledTraits yields empty set",
            dump = {
                "traits": [
                    {"enabledTraits": [], "name": "default"},
                    {"description": "The Foo trait", "name": "Foo"},
                ],
            },
            exp = [],
        ),
        struct(
            msg = "transitive trait enablement",
            dump = {
                "traits": [
                    {"enabledTraits": ["A"], "name": "default"},
                    {"enabledTraits": ["B"], "name": "A"},
                    {"enabledTraits": [], "name": "B"},
                    {"description": "Not enabled", "name": "C"},
                ],
            },
            exp = ["A", "B"],
        ),
        struct(
            msg = "no traits array (pre-6.1 packages)",
            dump = {},
            exp = [],
        ),
        struct(
            msg = "cyclic transitive enablement does not loop",
            dump = {
                "traits": [
                    {"enabledTraits": ["X"], "name": "default"},
                    {"enabledTraits": ["Y"], "name": "X"},
                    {"enabledTraits": ["X"], "name": "Y"},
                ],
            },
            exp = ["X", "Y"],
        ),
    ]

    for t in tests:
        actual = pkginfos.enabled_traits_from_dump_manifest(t.dump)
        asserts.equals(env, sorted(t.exp), actual, t.msg)

    return unittest.end(env)

enabled_traits_test = unittest.make(_enabled_traits_test)

# MARK: - Build Setting Filtering Tests

def _build_setting_trait_filtering_test(ctx):
    env = unittest.begin(ctx)

    enabled = ["Baz", "Foo"]

    tests = [
        struct(
            msg = "setting with no condition is always applied",
            dump = {
                "kind": {"define": {"_0": "ALWAYS"}},
                "tool": "swift",
            },
            exp_count = 1,
        ),
        struct(
            msg = "setting with enabled trait condition is applied",
            dump = {
                "condition": {"traits": ["Foo"]},
                "kind": {"define": {"_0": "HAS_FOO"}},
                "tool": "swift",
            },
            exp_count = 1,
        ),
        struct(
            msg = "setting with non-enabled trait condition is skipped",
            dump = {
                "condition": {"traits": ["Bar"]},
                "kind": {"define": {"_0": "HAS_BAR"}},
                "tool": "swift",
            },
            exp_count = 0,
        ),
        struct(
            msg = "setting requiring multiple traits, all enabled",
            dump = {
                "condition": {"traits": ["Foo", "Baz"]},
                "kind": {"define": {"_0": "HAS_BOTH"}},
                "tool": "swift",
            },
            exp_count = 1,
        ),
        struct(
            msg = "setting requiring multiple traits, only one enabled",
            dump = {
                "condition": {"traits": ["Foo", "Bar"]},
                "kind": {"define": {"_0": "HAS_BOTH"}},
                "tool": "swift",
            },
            exp_count = 0,
        ),
        struct(
            msg = "setting with traits and platforms, trait not enabled",
            dump = {
                "condition": {"platformNames": ["ios"], "traits": ["Bar"]},
                "kind": {"define": {"_0": "PLAT_TRAIT"}},
                "tool": "swift",
            },
            exp_count = 0,
        ),
        struct(
            msg = "setting with only trait condition (no platforms), trait enabled",
            dump = {
                "condition": {"traits": ["Foo"]},
                "kind": {"define": {"_0": "TRAIT_ONLY"}},
                "tool": "swift",
            },
            exp_count = 1,
        ),
    ]

    for t in tests:
        result = pkginfos.new_build_settings_from_json(t.dump, enabled)
        asserts.equals(
            env,
            t.exp_count,
            len(result),
            t.msg,
        )

    return unittest.end(env)

build_setting_trait_filtering_test = unittest.make(
    _build_setting_trait_filtering_test,
)

# MARK: - Target Dependency Trait Filtering Tests

def _target_dep_trait_filtering_test(ctx):
    env = unittest.begin(ctx)

    enabled = ["Foo"]

    tests = [
        struct(
            msg = "dep with no condition is always included",
            dump = {"byName": ["SomeDep", None]},
            exp_not_none = True,
        ),
        struct(
            msg = "dep with enabled trait condition is included",
            dump = {"byName": ["FooDep", {"traits": ["Foo"]}]},
            exp_not_none = True,
        ),
        struct(
            msg = "dep with non-enabled trait condition is excluded",
            dump = {"byName": ["BarDep", {"traits": ["Bar"]}]},
            exp_not_none = False,
        ),
        struct(
            msg = "dep requiring multiple traits, only one enabled",
            dump = {"byName": ["BothDep", {"traits": ["Foo", "Bar"]}]},
            exp_not_none = False,
        ),
        struct(
            msg = "dep with platform condition only is included",
            dump = {"byName": ["PlatDep", {"platformNames": ["ios"]}]},
            exp_not_none = True,
        ),
    ]

    for t in tests:
        result = pkginfos.new_target_dependency_from_dump_json_map(
            t.dump,
            enabled,
        )
        if t.exp_not_none:
            asserts.true(env, result != None, t.msg + " (expected not None)")
        else:
            asserts.equals(env, None, result, t.msg)

    return unittest.end(env)

target_dep_trait_filtering_test = unittest.make(
    _target_dep_trait_filtering_test,
)

# MARK: - Test Suite

def pkginfo_traits_test_suite():
    return unittest.suite(
        "pkginfo_traits_tests",
        enabled_traits_test,
        build_setting_trait_filtering_test,
        target_dep_trait_filtering_test,
    )
