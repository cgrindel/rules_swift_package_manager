"""Tests for `manifest_shapes` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:manifest_shapes.bzl", "manifest_shapes")
load(
    ":slice_manifests.bzl",
    "DESC_JSON",
    "DUMP_JSON",
    "LEAF_PKG_DESC_JSON",
    "LEAF_PKG_DUMP_JSON",
    "LOCAL_PKG_DESC_JSON",
    "LOCAL_PKG_DUMP_JSON",
)

def _check(dump, desc):
    return manifest_shapes.check(dump, desc)

def _fixtures_pass_test(ctx):
    env = unittest.begin(ctx)

    for dump, desc in [
        (DUMP_JSON, DESC_JSON),
        (LOCAL_PKG_DUMP_JSON, LOCAL_PKG_DESC_JSON),
        (LEAF_PKG_DUMP_JSON, LEAF_PKG_DESC_JSON),
    ]:
        asserts.equals(env, None, _check(json.decode(dump), json.decode(desc)))

    return unittest.end(env)

fixtures_pass_test = unittest.make(_fixtures_pass_test)

def _top_level_keys_test(ctx):
    env = unittest.begin(ctx)

    desc = json.decode(DESC_JSON)
    asserts.equals(
        env,
        "dump: missing `toolsVersion`",
        _check({"name": "x"}, desc),
    )

    dump = json.decode(DUMP_JSON)
    dump["targets"] = {}
    asserts.equals(
        env,
        "dump: `targets` is a dict, expected a list",
        _check(dump, desc),
    )

    dump = json.decode(DUMP_JSON)
    dump["toolsVersion"] = {}
    asserts.equals(
        env,
        "dump: missing `toolsVersion._version`",
        _check(dump, desc),
    )

    dump = json.decode(DUMP_JSON)
    dump.pop("swiftLanguageVersions")
    asserts.equals(
        env,
        "dump: missing `swiftLanguageVersions`",
        _check(dump, desc),
    )

    dump = json.decode(DUMP_JSON)
    asserts.equals(
        env,
        "desc: missing `path`",
        _check(dump, {"name": "MyPkg"}),
    )

    return unittest.end(env)

top_level_keys_test = unittest.make(_top_level_keys_test)

def _item_keys_test(ctx):
    env = unittest.begin(ctx)

    dump = json.decode(DUMP_JSON)
    dump["targets"][0].pop("settings")
    asserts.equals(
        env,
        "dump target `MyLib`: missing `settings`",
        _check(dump, json.decode(DESC_JSON)),
    )

    desc = json.decode(DESC_JSON)
    desc["targets"][0].pop("c99name")
    asserts.equals(
        env,
        "desc target `MyLib`: missing `c99name`",
        _check(json.decode(DUMP_JSON), desc),
    )

    dump = json.decode(DUMP_JSON)
    dump["products"][0].pop("type")
    asserts.equals(
        env,
        "dump product `MyLib`: missing `type`",
        _check(dump, json.decode(DESC_JSON)),
    )

    dump = json.decode(DUMP_JSON)
    dump["platforms"] = ["macos"]
    asserts.equals(
        env,
        "dump platform: not an object",
        _check(dump, json.decode(DESC_JSON)),
    )

    return unittest.end(env)

item_keys_test = unittest.make(_item_keys_test)

def _dump_and_desc_agree_test(ctx):
    env = unittest.begin(ctx)

    # An extra desc target is harmless; the parser only looks up dump targets.
    desc = json.decode(DESC_JSON)
    desc["targets"].append(dict(desc["targets"][0], name = "Extra"))
    asserts.equals(env, None, _check(json.decode(DUMP_JSON), desc))

    desc = json.decode(DESC_JSON)
    desc["targets"] = []
    asserts.equals(
        env,
        "target `MyLib` is in dump but not in desc",
        _check(json.decode(DUMP_JSON), desc),
    )

    desc = json.decode(DESC_JSON)
    desc["dependencies"].append({
        "identity": "swift-log",
        "type": "sourceControl",
        "url": "https://github.com/apple/swift-log",
    })
    asserts.equals(
        env,
        "dependency `swift-log` is in desc but not in dump",
        _check(json.decode(DUMP_JSON), desc),
    )

    return unittest.end(env)

dump_and_desc_agree_test = unittest.make(_dump_and_desc_agree_test)

def _dependency_shapes_test(ctx):
    env = unittest.begin(ctx)

    dump = json.decode(DUMP_JSON)
    for deps, want in [
        ([{}], "desc dependency: missing `identity`"),
        (["x"], "desc dependency: not an object"),
        (
            [{"identity": "local_pkg", "type": "fileSystem"}],
            "desc dependency `local_pkg`: missing `path`",
        ),
        (
            [{"identity": "local_pkg", "type": "sourceControl"}],
            "desc dependency `local_pkg`: missing `url`",
        ),
        (
            [{"identity": "local_pkg", "type": "other"}],
            "desc dependency `local_pkg`: unknown `type` \"other\"",
        ),
        (
            [{"identity": "local_pkg"}],
            "desc dependency `local_pkg`: unknown `type` null",
        ),
        ([{"identity": "local_pkg", "type": "registry"}], None),
    ]:
        desc = json.decode(DESC_JSON)
        desc["dependencies"] = deps
        asserts.equals(env, want, _check(dump, desc))

    want = (
        "dump dependency: no `sourceControl`, `fileSystem`, or `registry` " +
        "entry with an `identity`"
    )
    for deps in [[{}], [{"fileSystem": [{}]}], [{"sourceControl": []}], ["x"]]:
        dump = json.decode(DUMP_JSON)
        dump["dependencies"] = deps
        asserts.equals(env, want, _check(dump, json.decode(DESC_JSON)))

    return unittest.end(env)

dependency_shapes_test = unittest.make(_dependency_shapes_test)

def _unused_desc_target_needs_only_name_test(ctx):
    env = unittest.begin(ctx)

    desc = json.decode(DESC_JSON)
    desc["targets"].append({"name": "Tests"})
    asserts.equals(env, None, _check(json.decode(DUMP_JSON), desc))

    desc["targets"].append({"path": "Sources/Nameless"})
    asserts.equals(
        env,
        "desc target: missing `name`",
        _check(json.decode(DUMP_JSON), desc),
    )

    return unittest.end(env)

unused_desc_target_needs_only_name_test = unittest.make(
    _unused_desc_target_needs_only_name_test,
)

def manifest_shapes_test_suite():
    return unittest.suite(
        "manifest_shapes_tests",
        fixtures_pass_test,
        top_level_keys_test,
        item_keys_test,
        dump_and_desc_agree_test,
        dependency_shapes_test,
        unused_desc_target_needs_only_name_test,
    )
