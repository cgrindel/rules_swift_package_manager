"""Tests for `slices` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:slices.bzl", "slices")

def _new_slice(dump_ids = ["_main", "swift-log"], desc_ids = ["_main", "swift-log"], dump_pkg = "swift/macos"):
    return slices.new(
        config = Label("@@//config:macos"),
        swift = Label("@@//:Package.swift"),
        resolved = Label("@@//swift/macos:Package.resolved"),
        dump_manifests = {
            i: Label("@@//{}:swift_deps_cache/{}/dump.json".format(dump_pkg, i))
            for i in dump_ids
        },
        desc_manifests = {
            i: Label("@@//swift/macos:swift_deps_cache/{}/desc.json".format(i))
            for i in desc_ids
        },
        is_root = True,
        is_dev = False,
    )

def _new_derives_dir_and_package_label_test(ctx):
    env = unittest.begin(ctx)

    s = slices.new(
        config = Label("@@//config:macos"),
        swift = Label("@@//:Package.swift"),
        resolved = Label("@@//swift/macos:Package.resolved"),
        dump_manifests = {"swift-log": Label("@@//swift/macos:a"), "_main": Label("@@//swift/macos:b")},
        desc_manifests = {"_main": Label("@@//swift/macos:c")},
        is_root = True,
        is_dev = False,
    )
    asserts.equals(env, "swift/macos", s.dir)
    asserts.equals(env, "@@//swift/macos", s.package_label)
    asserts.equals(env, "@@//config:macos", s.config)
    asserts.equals(env, ["_main", "swift-log"], s.identities)
    asserts.true(env, s.is_root)
    asserts.false(env, s.is_dev)

    # A string config is kept as given.
    asserts.equals(env, None, s.netrc)
    asserts.equals(env, None, s.registries)
    asserts.false(env, s.make_files_read_only)

    s2 = slices.new("//x:y", s.swift, s.resolved, {}, {}, False, True)
    asserts.equals(env, "//x:y", s2.config)

    s3 = slices.new(
        "//x:y",
        s.swift,
        s.resolved,
        {},
        {},
        False,
        True,
        netrc = Label("@@//:.netrc"),
        registries = Label("@@//:registries.json"),
        make_files_read_only = True,
    )
    asserts.equals(env, Label("@@//:.netrc"), s3.netrc)
    asserts.equals(env, Label("@@//:registries.json"), s3.registries)
    asserts.true(env, s3.make_files_read_only)

    return unittest.end(env)

new_derives_dir_and_package_label_test = unittest.make(
    _new_derives_dir_and_package_label_test,
)

def _validate_ok_test(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, None, slices.validate(_new_slice()))
    return unittest.end(env)

validate_ok_test = unittest.make(_validate_ok_test)

def _validate_key_mismatch_test(ctx):
    env = unittest.begin(ctx)

    err = slices.validate(_new_slice(
        dump_ids = ["_main", "b-pkg", "a-pkg"],
        desc_ids = ["_main", "c-pkg"],
    ))
    asserts.equals(
        env,
        "slice `swift/macos`: dump_manifests and desc_manifests have " +
        "different identities; differing: a-pkg, b-pkg, c-pkg",
        err,
    )

    return unittest.end(env)

validate_key_mismatch_test = unittest.make(_validate_key_mismatch_test)

def _validate_missing_main_test(ctx):
    env = unittest.begin(ctx)

    err = slices.validate(_new_slice(
        dump_ids = ["swift-log"],
        desc_ids = ["swift-log"],
    ))
    asserts.equals(
        env,
        "slice `swift/macos`: dump_manifests is missing the `_main` identity",
        err,
    )

    return unittest.end(env)

validate_missing_main_test = unittest.make(_validate_missing_main_test)

def _validate_empty_manifests_test(ctx):
    env = unittest.begin(ctx)

    # What `init` writes before the first cache run.
    err = slices.validate(_new_slice(dump_ids = [], desc_ids = []))
    asserts.equals(env, None, err)

    return unittest.end(env)

validate_empty_manifests_test = unittest.make(_validate_empty_manifests_test)

def _is_v2_tag_test(ctx):
    env = unittest.begin(ctx)

    label = Label("@@//swift/macos:swift_deps_cache/_main/dump.json")
    asserts.false(env, slices.is_v2_tag(struct(config = None, dump_manifests = {})))
    asserts.true(env, slices.is_v2_tag(struct(
        config = Label("@@//config:macos"),
        dump_manifests = {},
    )))
    asserts.true(env, slices.is_v2_tag(struct(
        config = None,
        dump_manifests = {"_main": label},
    )))

    return unittest.end(env)

is_v2_tag_test = unittest.make(_is_v2_tag_test)

def _validate_label_outside_slice_test(ctx):
    env = unittest.begin(ctx)

    err = slices.validate(_new_slice(dump_pkg = "swift/linux"))
    asserts.true(env, err != None)
    asserts.true(env, "swift-log" in err or "_main" in err)
    asserts.true(env, "@@//swift/linux:swift_deps_cache/_main/dump.json" in err)
    asserts.true(env, "swift/macos" in err)

    return unittest.end(env)

validate_label_outside_slice_test = unittest.make(
    _validate_label_outside_slice_test,
)

def _cache_label_test(ctx):
    env = unittest.begin(ctx)

    s = _new_slice()
    asserts.equals(
        env,
        "@@//swift/macos:swift_deps_cache/swift-log/dump.json",
        str(slices.cache_label(s, "swift-log", "dump.json")),
    )

    return unittest.end(env)

cache_label_test = unittest.make(_cache_label_test)

def slices_test_suite(name = "slices_tests"):
    return unittest.suite(
        name,
        new_derives_dir_and_package_label_test,
        validate_ok_test,
        validate_key_mismatch_test,
        validate_missing_main_test,
        validate_empty_manifests_test,
        is_v2_tag_test,
        validate_label_outside_slice_test,
        cache_label_test,
    )
