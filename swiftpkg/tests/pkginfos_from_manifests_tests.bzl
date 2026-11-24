"""Tests for `pkginfos.new_from_manifests`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load(":fixtures/slices/manifests.bzl", "DESC_JSON", "DUMP_JSON")

# `_new_from_parsed_json` only touches the ctx for source info and resource
# expansion. The fixture has neither, so an empty struct is enough.
_FAKE_CTX = struct()

_DIRECTORY = "/repo/external/swiftpkg_mypkg"
_SOURCE_DIRECTORY = "/ws/third_party/MyPkg"

def _local_dep(pkg_info):
    deps = [d for d in pkg_info.dependencies if d.identity == "local_pkg"]
    if len(deps) != 1:
        fail("Expected exactly one local_pkg dependency, got", deps)
    return deps[0]

def _relative_paths_are_absolutized_test(ctx):
    env = unittest.begin(ctx)

    desc_manifest = json.decode(DESC_JSON)
    pkg_info = pkginfos.new_from_manifests(
        _FAKE_CTX,
        directory = _DIRECTORY,
        dump_manifest = json.decode(DUMP_JSON),
        desc_manifest = desc_manifest,
        collect_src_info = False,
        source_directory = _SOURCE_DIRECTORY,
    )
    asserts.equals(env, _DIRECTORY, pkg_info.path)
    asserts.equals(
        env,
        "/ws/third_party/local_pkg",
        _local_dep(pkg_info).file_system.path,
    )

    # The caller's dicts are not mutated.
    asserts.equals(env, "./", desc_manifest["path"])
    asserts.equals(
        env,
        "../local_pkg",
        desc_manifest["dependencies"][0]["path"],
    )

    # Without `source_directory`, dependency paths resolve against `directory`.
    pkg_info = pkginfos.new_from_manifests(
        _FAKE_CTX,
        directory = _DIRECTORY,
        dump_manifest = json.decode(DUMP_JSON),
        desc_manifest = json.decode(DESC_JSON),
        collect_src_info = False,
    )
    asserts.equals(env, _DIRECTORY, pkg_info.path)
    asserts.equals(
        env,
        "/repo/external/local_pkg",
        _local_dep(pkg_info).file_system.path,
    )

    # Absolute paths are left unchanged.
    desc_manifest = json.decode(DESC_JSON)
    desc_manifest["path"] = "/abs/MyPkg"
    desc_manifest["dependencies"][0]["path"] = "/abs/local_pkg"
    pkg_info = pkginfos.new_from_manifests(
        _FAKE_CTX,
        directory = _DIRECTORY,
        dump_manifest = json.decode(DUMP_JSON),
        desc_manifest = desc_manifest,
        collect_src_info = False,
        source_directory = _SOURCE_DIRECTORY,
    )
    asserts.equals(env, "/abs/MyPkg", pkg_info.path)
    asserts.equals(
        env,
        "/abs/local_pkg",
        _local_dep(pkg_info).file_system.path,
    )

    return unittest.end(env)

relative_paths_are_absolutized_test = unittest.make(
    _relative_paths_are_absolutized_test,
)

def _matches_v1_parse_test(ctx):
    env = unittest.begin(ctx)

    actual = pkginfos.new_from_manifests(
        _FAKE_CTX,
        directory = _DIRECTORY,
        dump_manifest = json.decode(DUMP_JSON),
        desc_manifest = json.decode(DESC_JSON),
        collect_src_info = False,
        source_directory = _SOURCE_DIRECTORY,
    )

    desc_manifest = json.decode(DESC_JSON)
    desc_manifest["path"] = _DIRECTORY
    desc_manifest["dependencies"][0]["path"] = "/ws/third_party/local_pkg"
    expected = pkginfos.new_from_parsed_json(
        _FAKE_CTX,
        dump_manifest = json.decode(DUMP_JSON),
        desc_manifest = desc_manifest,
        collect_src_info = False,
    )

    asserts.equals(env, expected, actual)
    asserts.equals(env, "MyPkg", actual.name)
    asserts.equals(env, ["MyLib"], [t.name for t in actual.targets])

    return unittest.end(env)

matches_v1_parse_test = unittest.make(_matches_v1_parse_test)

def pkginfos_from_manifests_test_suite(name = "pkginfos_from_manifests_tests"):
    return unittest.suite(
        name,
        relative_paths_are_absolutized_test,
        matches_v1_parse_test,
    )
