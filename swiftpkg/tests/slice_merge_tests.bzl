"""Tests for `slice_merge` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//swiftpkg/internal:slice_merge.bzl",
    "slice_merge",
    "slice_merge_testing",
)

# MARK: - Helpers

def _pkg(pin_key, dump_text = "dump", desc_text = "desc", kind = "source_control"):
    return struct(
        kind = kind,
        pin_key = pin_key,
        dump_text = dump_text,
        desc_text = desc_text,
        dump_label = "dump_label_" + pin_key,
        desc_label = "desc_label_" + pin_key,
        local_path = None,
    )

def _stale_pkg(pin_key, kind = "source_control"):
    return struct(
        kind = kind,
        pin_key = pin_key,
        dump_text = None,
        desc_text = None,
        dump_label = None,
        desc_label = None,
        local_path = None,
    )

def _slice(config, pkgs, stale = False):
    return struct(
        config = config,
        dir = "/cache/" + config,
        stale = stale,
        pkgs = pkgs,
    )

def _group_summary(groups):
    return [(g.index, g.configs) for g in groups]

# MARK: - Tests

def _single_slice_identical_test(ctx):
    env = unittest.begin(ctx)

    foo = _pkg("foo@1")
    actual = slice_merge.merge([_slice("a", {"foo": foo})])

    asserts.equals(env, ["foo"], actual.keys())
    m = actual["foo"]
    asserts.equals(env, "source_control", m.kind)
    asserts.true(env, m.identical)
    asserts.false(env, m.any_stale)
    asserts.equals(env, [(1, ["a"])], _group_summary(m.groups))
    asserts.equals(env, foo, m.groups[0].entry)
    asserts.equals(env, [], m.stale_configs)

    return unittest.end(env)

single_slice_identical_test = unittest.make(_single_slice_identical_test)

def _two_equal_slices_identical_test(ctx):
    env = unittest.begin(ctx)

    foo_a = _pkg("foo@1")
    actual = slice_merge.merge([
        _slice("a", {"foo": foo_a}),
        _slice("b", {"foo": _pkg("foo@1")}),
    ])

    m = actual["foo"]
    asserts.true(env, m.identical)
    asserts.false(env, m.any_stale)
    asserts.equals(env, [(1, ["a", "b"])], _group_summary(m.groups))
    asserts.equals(env, foo_a, m.groups[0].entry)
    asserts.equals(env, [], m.stale_configs)

    return unittest.end(env)

two_equal_slices_identical_test = unittest.make(_two_equal_slices_identical_test)

def _different_pins_two_groups_test(ctx):
    env = unittest.begin(ctx)

    foo1 = _pkg("foo@1")
    foo2 = _pkg("foo@2")
    bar = _pkg("bar@1")
    actual = slice_merge.merge([
        _slice("a", {"bar": bar, "foo": foo1}),
        _slice("b", {"bar": _pkg("bar@1"), "foo": foo2}),
        _slice("c", {"bar": _pkg("bar@1"), "foo": _pkg("foo@1")}),
        # Same pin, different dump text: a separate group.
        _slice("d", {"bar": _pkg("bar@1"), "foo": _pkg("foo@1", dump_text = "x")}),
    ])

    asserts.equals(env, ["bar", "foo"], actual.keys())

    m = actual["foo"]
    asserts.false(env, m.identical)
    asserts.false(env, m.any_stale)
    asserts.equals(
        env,
        [(1, ["a", "c"]), (2, ["b"]), (3, ["d"])],
        _group_summary(m.groups),
    )
    asserts.equals(env, foo1, m.groups[0].entry)
    asserts.equals(env, foo2, m.groups[1].entry)
    asserts.equals(env, [], m.stale_configs)

    b = actual["bar"]
    asserts.true(env, b.identical)
    asserts.equals(env, [(1, ["a", "b", "c", "d"])], _group_summary(b.groups))

    return unittest.end(env)

different_pins_two_groups_test = unittest.make(_different_pins_two_groups_test)

def _stale_slice_forces_alias_test(ctx):
    env = unittest.begin(ctx)

    actual = slice_merge.merge([
        _slice("a", {"bar": _pkg("bar@1"), "foo": _pkg("foo@1")}),
        _slice("b", {"foo": _stale_pkg("foo@1")}, stale = True),
        _slice("c", {"bar": _pkg("bar@1"), "foo": _pkg("foo@1")}),
    ])

    asserts.equals(env, ["bar", "foo"], actual.keys())

    m = actual["foo"]
    asserts.false(env, m.identical)
    asserts.true(env, m.any_stale)
    asserts.equals(env, [(1, ["a", "c"])], _group_summary(m.groups))
    asserts.equals(env, ["b"], m.stale_configs)

    # bar is absent from the stale slice; still not identical.
    b = actual["bar"]
    asserts.false(env, b.identical)
    asserts.true(env, b.any_stale)
    asserts.equals(env, [(1, ["a", "c"])], _group_summary(b.groups))
    asserts.equals(env, ["b"], b.stale_configs)

    return unittest.end(env)

stale_slice_forces_alias_test = unittest.make(_stale_slice_forces_alias_test)

def _identity_only_in_stale_slice_test(ctx):
    env = unittest.begin(ctx)

    actual = slice_merge.merge([
        _slice("a", {"bar": _pkg("bar@1")}),
        _slice("b", {"foo": _stale_pkg("foo@1", kind = "registry")}, stale = True),
    ])

    asserts.equals(env, ["bar", "foo"], actual.keys())
    m = actual["foo"]
    asserts.equals(env, "registry", m.kind)
    asserts.false(env, m.identical)
    asserts.true(env, m.any_stale)
    asserts.equals(env, [], m.groups)

    # "a" is fresh but lacks foo; "b" is stale.
    asserts.equals(env, ["a", "b"], m.stale_configs)

    return unittest.end(env)

identity_only_in_stale_slice_test = unittest.make(_identity_only_in_stale_slice_test)

def _fresh_slice_lacking_identity_test(ctx):
    env = unittest.begin(ctx)

    actual = slice_merge.merge([
        _slice("a", {"bar": _pkg("bar@1"), "foo": _pkg("foo@1")}),
        _slice("b", {"bar": _pkg("bar@1")}),
    ])

    m = actual["foo"]
    asserts.false(env, m.identical)
    asserts.false(env, m.any_stale)
    asserts.equals(env, [(1, ["a"])], _group_summary(m.groups))
    asserts.equals(env, ["b"], m.stale_configs)
    asserts.true(env, actual["bar"].identical)

    return unittest.end(env)

fresh_slice_lacking_identity_test = unittest.make(_fresh_slice_lacking_identity_test)

def _kind_conflict_fails_test(ctx):
    env = unittest.begin(ctx)

    result = slice_merge_testing.merge_or_error([
        _slice("a", {"foo": _pkg("foo@1")}),
        _slice("b", {"foo": _pkg("foo@1", kind = "registry")}),
    ])

    asserts.equals(env, None, result.result)
    asserts.true(env, result.error != None)
    asserts.true(env, "foo" in result.error)
    asserts.true(env, "source_control" in result.error)
    asserts.true(env, "registry" in result.error)

    ok = slice_merge_testing.merge_or_error([
        _slice("a", {"foo": _pkg("foo@1")}),
    ])
    asserts.equals(env, None, ok.error)
    asserts.equals(env, ["foo"], ok.result.keys())

    return unittest.end(env)

kind_conflict_fails_test = unittest.make(_kind_conflict_fails_test)

def _stale_kind_conflict_is_ignored_test(ctx):
    env = unittest.begin(ctx)

    # The stale slice's live Package.resolved still pins foo remotely while
    # the fresh slice now has it as a local package.
    result = slice_merge_testing.merge_or_error([
        _slice("a", {"foo": _pkg("foo@1", kind = "local")}),
        _slice("b", {"foo": _stale_pkg("foo@1")}, stale = True),
    ])

    asserts.equals(env, None, result.error)
    m = result.result["foo"]
    asserts.equals(env, "local", m.kind)
    asserts.false(env, m.identical)
    asserts.true(env, m.any_stale)
    asserts.equals(env, [(1, ["a"])], _group_summary(m.groups))
    asserts.equals(env, ["b"], m.stale_configs)

    # Stale first in input order: the fresh kind still wins.
    result = slice_merge_testing.merge_or_error([
        _slice("b", {"foo": _stale_pkg("foo@1")}, stale = True),
        _slice("a", {"foo": _pkg("foo@1", kind = "local")}),
    ])
    asserts.equals(env, None, result.error)
    asserts.equals(env, "local", result.result["foo"].kind)

    return unittest.end(env)

stale_kind_conflict_is_ignored_test = unittest.make(
    _stale_kind_conflict_is_ignored_test,
)

def _repo_name_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        "swiftpkg_swift_argument_parser__slice_1",
        slice_merge.repo_name("swift-argument-parser", 1),
    )
    asserts.equals(
        env,
        "swiftpkg_foo__slice_12",
        slice_merge.repo_name("foo", 12),
    )

    return unittest.end(env)

repo_name_test = unittest.make(_repo_name_test)

def slice_merge_test_suite(name = "slice_merge_tests"):
    return unittest.suite(
        name,
        single_slice_identical_test,
        two_equal_slices_identical_test,
        different_pins_two_groups_test,
        stale_slice_forces_alias_test,
        identity_only_in_stale_slice_test,
        fresh_slice_lacking_identity_test,
        kind_conflict_fails_test,
        stale_kind_conflict_is_ignored_test,
        repo_name_test,
    )
