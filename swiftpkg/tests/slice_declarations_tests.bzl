"""Tests for `slice_declarations` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//swiftpkg/bzlmod:slice_declarations.bzl",
    "slice_declarations",
    "slice_declarations_testing",
)
load("//swiftpkg/internal:slices.bzl", "slices")
load("//swiftpkg/internal:staleness.bzl", "staleness")
load(":fake_module_ctx.bzl", "fake_module_ctx")
load(
    ":slice_manifests.bzl",
    "DESC_JSON",
    "DUMP_JSON",
    "LEAF_PKG_DESC_JSON",
    "LEAF_PKG_DUMP_JSON",
    "LOCAL_PKG_DESC_JSON",
    "LOCAL_PKG_DUMP_JSON",
    "RESOLVED_JSON",
)

# MARK: - Fixtures

_CACHE = "/ws/swift/macos/swift_deps_cache"
_ALL_IDS = ["_main", "leaf_pkg", "local_pkg", "swift-log"]
_SWIFT_LOG_REVISION = "96a2f8a0fa41e9e09af4585e2724c4e825410b91"
_SWIFT_LOG_DUMP = """{"name": "swift-log"}"""
_SWIFT_LOG_DESC = """{"name": "swift-log", "path": "./"}"""

def _cache(identity, basename):
    return "{}/{}/{}".format(_CACHE, identity, basename)

def _cache_label(identity, basename):
    return Label("@@//swift/macos:swift_deps_cache/{}/{}".format(
        identity,
        basename,
    ))

def _new_slice(identities = _ALL_IDS):
    return slices.new(
        config = Label("@@//config:macos"),
        swift = Label("@@//app:Package.swift"),
        resolved = Label("@@//swift/macos:Package.resolved"),
        dump_manifests = {i: _cache_label(i, "dump.json") for i in identities},
        desc_manifests = {i: _cache_label(i, "desc.json") for i in identities},
        is_root = True,
        is_dev = False,
    )

def _fresh_files(resolved = RESOLVED_JSON):
    """A fresh cache for `MyPkg` in `/ws/app` with the slice `swift/macos`."""
    files = {
        "/ws/app/Package.swift": "// MyPkg",
        "/ws/leaf_pkg/Package.swift": "// leaf_pkg",
        "/ws/local_pkg/Package.swift": "// local_pkg",
        _cache("_main", "Package.swift.cached"): "// MyPkg",
        _cache("_main", "desc.json"): DESC_JSON,
        _cache("_main", "dump.json"): DUMP_JSON,
        _cache("_main", "flags.cached"): staleness.render_flags(None),
        _cache("_main", "swift_version.txt"): "6.0\n",
        _cache("leaf_pkg", "Package.swift.cached"): "// leaf_pkg",
        _cache("leaf_pkg", "desc.json"): LEAF_PKG_DESC_JSON,
        _cache("leaf_pkg", "dump.json"): LEAF_PKG_DUMP_JSON,
        _cache("local_pkg", "Package.swift.cached"): "// local_pkg",
        _cache("local_pkg", "desc.json"): LOCAL_PKG_DESC_JSON,
        _cache("local_pkg", "dump.json"): LOCAL_PKG_DUMP_JSON,
        _cache("swift-log", "desc.json"): _SWIFT_LOG_DESC,
        _cache("swift-log", "dump.json"): _SWIFT_LOG_DUMP,
    }
    if resolved != None:
        files["/ws/swift/macos/Package.resolved"] = resolved
        files[_cache("_main", "Package.resolved.cached")] = resolved
    return files

def _evaluate(files, slice = None, config_pkgs = {}):
    return slice_declarations_testing.evaluate_or_error(
        fake_module_ctx.new(files = files),
        slice if slice != None else _new_slice(),
        None,
        config_pkgs,
        directory = "/ws/app",
        bazel_workspace_root = "/ws",
        collect_inputs = fake_module_ctx.staleness_collect(files),
    )

def _registry_resolved():
    resolved = json.decode(RESOLVED_JSON)
    resolved["pins"].append({
        "identity": "apple.swift-collections",
        "kind": "registry",
        "location": "",
        "state": {"version": "1.1.0"},
    })
    return json.encode_indent(resolved)

def _tag(
        dir = "swift/macos",
        config = Label("@@//config:macos"),
        dump_ids = ["_main"],
        desc_ids = None,
        is_dev = False):
    if desc_ids == None:
        desc_ids = dump_ids
    return struct(
        config = config,
        swift = Label("@@//:Package.swift"),
        resolved = Label("@@//{}:Package.resolved".format(dir)),
        dump_manifests = {
            i: Label("@@//{}:swift_deps_cache/{}/dump.json".format(dir, i))
            for i in dump_ids
        },
        desc_manifests = {
            i: Label("@@//{}:swift_deps_cache/{}/desc.json".format(dir, i))
            for i in desc_ids
        },
        is_dev = is_dev,
    )

def _module(tags, is_root = True):
    return struct(
        is_root = is_root,
        name = "my_app" if is_root else "some_dep",
        tags = struct(from_package = tags),
    )

def _collect(modules):
    return slice_declarations_testing.collect_or_error(
        modules,
        lambda tag: tag.is_dev,
    )

# MARK: - evaluate

def _fresh_slice_lists_all_identities_test(ctx):
    env = unittest.begin(ctx)

    actual = _evaluate(_fresh_files())
    asserts.equals(env, None, actual.error)
    ev = actual.result
    asserts.false(env, ev.stale)
    asserts.equals(env, [], ev.reasons)
    asserts.equals(env, "MyPkg", ev.pkg_info.name)
    asserts.equals(env, {}, ev.module_aliases_by_id)

    # Direct local dep, a pin, and a transitive local dep. Never `_main`.
    asserts.equals(
        env,
        ["leaf_pkg", "local_pkg", "swift-log"],
        sorted(ev.pkgs.keys()),
    )

    local = ev.pkgs["local_pkg"]
    asserts.equals(env, "local", local.kind)
    asserts.equals(env, "path:local_pkg", local.pin_key)
    asserts.equals(env, "local_pkg", local.local_path)
    asserts.equals(env, _cache_label("local_pkg", "dump.json"), local.dump_label)
    asserts.equals(env, _cache_label("local_pkg", "desc.json"), local.desc_label)
    asserts.equals(env, LOCAL_PKG_DUMP_JSON, local.dump_text)
    asserts.equals(env, LOCAL_PKG_DESC_JSON, local.desc_text)
    asserts.equals(env, "local_pkg", local.dep.name)
    asserts.equals(env, "/ws/local_pkg", local.dep.file_system.path)

    leaf = ev.pkgs["leaf_pkg"]
    asserts.equals(env, "local", leaf.kind)
    asserts.equals(env, "path:leaf_pkg", leaf.pin_key)
    asserts.equals(env, "leaf_pkg", leaf.local_path)
    asserts.equals(env, LEAF_PKG_DUMP_JSON, leaf.dump_text)
    asserts.equals(env, "/ws/leaf_pkg", leaf.dep.file_system.path)

    log = ev.pkgs["swift-log"]
    asserts.equals(env, "source_control", log.kind)
    asserts.equals(
        env,
        "https://github.com/apple/swift-log@" + _SWIFT_LOG_REVISION,
        log.pin_key,
    )
    asserts.equals(env, None, log.local_path)
    asserts.equals(env, _cache_label("swift-log", "dump.json"), log.dump_label)
    asserts.equals(env, _SWIFT_LOG_DUMP, log.dump_text)
    asserts.equals(env, _SWIFT_LOG_DESC, log.desc_text)
    pin = log.dep.source_control.pin
    asserts.equals(env, "https://github.com/apple/swift-log", pin.location)
    asserts.equals(env, _SWIFT_LOG_REVISION, pin.state.revision)
    asserts.equals(env, "1.6.2", pin.state.version)

    return unittest.end(env)

fresh_slice_lists_all_identities_test = unittest.make(
    _fresh_slice_lists_all_identities_test,
)

def _assert_stale_pkgs(env, ev, ids):
    asserts.equals(env, ids, sorted(ev.pkgs.keys()))
    for identity in ids:
        entry = ev.pkgs[identity]
        if identity == "swift-log":
            asserts.equals(env, "source_control", entry.kind)
            asserts.equals(
                env,
                "https://github.com/apple/swift-log@" + _SWIFT_LOG_REVISION,
                entry.pin_key,
            )
        else:
            asserts.equals(env, "unknown", entry.kind, identity)
            asserts.equals(env, None, entry.pin_key, identity)

        # Stale entries carry no manifests.
        asserts.false(env, hasattr(entry, "dump_text"), identity)
    asserts.equals(env, None, ev.pkg_info)
    asserts.equals(env, {}, ev.module_aliases_by_id)

def _missing_dump_marks_stale_and_keeps_names_test(ctx):
    env = unittest.begin(ctx)

    files = _fresh_files()
    files.pop(_cache("local_pkg", "dump.json"))
    actual = _evaluate(files)
    asserts.equals(env, None, actual.error)
    ev = actual.result
    asserts.true(env, ev.stale)
    asserts.equals(
        env,
        ["local_pkg/dump.json: missing cached copy"],
        ev.reasons,
    )
    _assert_stale_pkgs(env, ev, ["leaf_pkg", "local_pkg", "swift-log"])

    return unittest.end(env)

missing_dump_marks_stale_and_keeps_names_test = unittest.make(
    _missing_dump_marks_stale_and_keeps_names_test,
)

def _changed_manifest_marks_stale_test(ctx):
    env = unittest.begin(ctx)

    files = _fresh_files()
    files["/ws/app/Package.swift"] = "// MyPkg, edited"
    actual = _evaluate(files)
    asserts.equals(env, None, actual.error)
    ev = actual.result
    asserts.true(env, ev.stale)
    asserts.equals(
        env,
        ["_main/Package.swift.cached: differs from cached copy"],
        ev.reasons,
    )
    _assert_stale_pkgs(env, ev, ["leaf_pkg", "local_pkg", "swift-log"])

    return unittest.end(env)

changed_manifest_marks_stale_test = unittest.make(
    _changed_manifest_marks_stale_test,
)

def _unlisted_identity_marks_stale_test(ctx):
    env = unittest.begin(ctx)

    # The staleness inputs are fine, but the slice does not list `leaf_pkg`,
    # which `local_pkg` reaches by path.
    actual = _evaluate(
        _fresh_files(),
        slice = _new_slice(["_main", "local_pkg", "swift-log"]),
    )
    asserts.equals(env, None, actual.error)
    ev = actual.result
    asserts.true(env, ev.stale)
    asserts.equals(
        env,
        [
            "leaf_pkg/dump.json: not listed in the slice",
            "leaf_pkg/desc.json: not listed in the slice",
        ],
        ev.reasons,
    )
    _assert_stale_pkgs(env, ev, ["local_pkg", "swift-log"])

    return unittest.end(env)

unlisted_identity_marks_stale_test = unittest.make(
    _unlisted_identity_marks_stale_test,
)

def _structurally_bad_manifest_marks_stale_test(ctx):
    env = unittest.begin(ctx)

    # Valid JSON, but not a manifest the parser can read.
    files = _fresh_files()
    files[_cache("local_pkg", "dump.json")] = """{"name": "x"}"""
    actual = _evaluate(files)
    asserts.equals(env, None, actual.error)
    ev = actual.result
    asserts.true(env, ev.stale)
    asserts.equals(
        env,
        ["local_pkg/dump.json: dump: missing `toolsVersion`"],
        ev.reasons,
    )
    _assert_stale_pkgs(env, ev, ["leaf_pkg", "local_pkg", "swift-log"])

    return unittest.end(env)

structurally_bad_manifest_marks_stale_test = unittest.make(
    _structurally_bad_manifest_marks_stale_test,
)

def _malformed_pin_is_skipped_test(ctx):
    env = unittest.begin(ctx)

    resolved = json.decode(RESOLVED_JSON)
    resolved["pins"].append({"kind": "remoteSourceControl"})
    actual = _evaluate(_fresh_files(resolved = json.encode_indent(resolved)))
    asserts.equals(env, None, actual.error)
    asserts.false(env, actual.result.stale)
    asserts.equals(
        env,
        ["leaf_pkg", "local_pkg", "swift-log"],
        sorted(actual.result.pkgs.keys()),
    )

    return unittest.end(env)

malformed_pin_is_skipped_test = unittest.make(_malformed_pin_is_skipped_test)

def _registry_pin_fails_with_2699_test(ctx):
    env = unittest.begin(ctx)

    files = _fresh_files(resolved = _registry_resolved())
    actual = _evaluate(files)
    asserts.equals(
        env,
        "registry package `apple.swift-collections` is not supported by v2 " +
        "yet; see https://github.com/cgrindel/rules_swift_package_manager/issues/2699",
        actual.error,
    )
    asserts.equals(env, None, actual.result)

    # A stale slice never fails; it reports the registry pin's kind.
    files["/ws/app/Package.swift"] = "// MyPkg, edited"
    actual = _evaluate(files)
    asserts.equals(env, None, actual.error)
    asserts.true(env, actual.result.stale)
    entry = actual.result.pkgs["apple.swift-collections"]
    asserts.equals(env, "registry", entry.kind)
    asserts.equals(env, "registry:apple.swift-collections@1.1.0", entry.pin_key)

    return unittest.end(env)

registry_pin_fails_with_2699_test = unittest.make(
    _registry_pin_fails_with_2699_test,
)

def _no_resolved_file_means_no_pins_test(ctx):
    env = unittest.begin(ctx)

    actual = _evaluate(
        _fresh_files(resolved = None),
        slice = _new_slice(["_main", "leaf_pkg", "local_pkg"]),
    )
    asserts.equals(env, None, actual.error)
    ev = actual.result
    asserts.false(env, ev.stale)
    asserts.equals(env, [], ev.reasons)
    asserts.equals(env, ["leaf_pkg", "local_pkg"], sorted(ev.pkgs.keys()))

    return unittest.end(env)

no_resolved_file_means_no_pins_test = unittest.make(
    _no_resolved_file_means_no_pins_test,
)

def _patch_files_by_identity_test(ctx):
    env = unittest.begin(ctx)

    # `local_pkg` is named `LocalPackage` in the root manifest.
    dump = json.decode(DUMP_JSON)
    dump["dependencies"][0]["fileSystem"][0]["nameForTargetDependencyResolutionOnly"] = "LocalPackage"
    files = _fresh_files()
    files[_cache("_main", "dump.json")] = json.encode(dump)

    by_identity = Label("@@//patches:by_identity.patch")
    by_repo = Label("@@//patches:by_repo.patch")
    by_name = Label("@@//patches:by_name.patch")
    config_pkgs = {
        "LocalPackage": struct(name = "LocalPackage", patches = [by_name]),
        "Swift-Log": struct(name = "Swift-Log", patches = [by_identity]),
        "no_patches": struct(name = "no_patches", patches = []),
        "swiftpkg_leaf_pkg": struct(name = "swiftpkg_leaf_pkg", patches = [by_repo]),
        "unknown": struct(name = "unknown", patches = [by_name]),
    }
    actual = slice_declarations_testing.patch_files_by_identity(
        fake_module_ctx.new(files = files),
        _new_slice(),
        config_pkgs,
    )
    asserts.equals(
        env,
        {
            "leaf_pkg": [by_repo],
            "local_pkg": [by_name],
            "swift-log": [by_identity],
        },
        actual,
    )

    return unittest.end(env)

patch_files_by_identity_test = unittest.make(_patch_files_by_identity_test)

def _stale_warning_and_merge_entry_test(ctx):
    env = unittest.begin(ctx)

    files = _fresh_files()
    files["/ws/app/Package.swift"] = "// MyPkg, edited"
    ev = _evaluate(files).result
    asserts.equals(
        env,
        "WARNING: slice `swift/macos` (config `@@//config:macos`) is stale; " +
        "run `bazel run @swift_package//:cache` under flags that select " +
        "that config. Reasons: _main/Package.swift.cached: differs from " +
        "cached copy",
        slice_declarations_testing.stale_warning(ev.slice, ev.reasons),
    )

    entry = slice_declarations.to_merge_entry(ev)
    asserts.equals(env, "@@//config:macos", entry.config)
    asserts.equals(env, "swift/macos", entry.dir)
    asserts.true(env, entry.stale)
    asserts.equals(env, ev.pkgs, entry.pkgs)

    return unittest.end(env)

stale_warning_and_merge_entry_test = unittest.make(
    _stale_warning_and_merge_entry_test,
)

def _bazel_workspace_root_test(ctx):
    env = unittest.begin(ctx)

    bazel_workspace_root = slice_declarations_testing.bazel_workspace_root
    asserts.equals(
        env,
        "/ws",
        bazel_workspace_root(Label("@@//app:Package.swift"), "/ws/app/Package.swift"),
    )
    asserts.equals(
        env,
        "/ws",
        bazel_workspace_root(Label("@@//:Package.swift"), "/ws/Package.swift"),
    )

    return unittest.end(env)

bazel_workspace_root_test = unittest.make(_bazel_workspace_root_test)

# MARK: - collect

def _collect_builds_slices_in_order_test(ctx):
    env = unittest.begin(ctx)

    v1 = _tag(dump_ids = [])
    actual = _collect([
        _module([_tag(), v1, _tag(dir = "swift/linux", config = Label("@@//config:linux"), is_dev = True)]),
        _module([_tag(dir = "dep/macos")], is_root = False),
    ])
    asserts.equals(env, None, actual.error)
    asserts.equals(
        env,
        ["swift/macos", "swift/linux", "dep/macos"],
        [s.dir for s in actual.result],
    )
    asserts.equals(env, [True, True, False], [s.is_root for s in actual.result])
    asserts.equals(env, [False, True, False], [s.is_dev for s in actual.result])

    return unittest.end(env)

collect_builds_slices_in_order_test = unittest.make(
    _collect_builds_slices_in_order_test,
)

def _collect_requires_config_test(ctx):
    env = unittest.begin(ctx)

    actual = _collect([_module([_tag(config = None)])])
    asserts.equals(
        env,
        "from_package `@@//:Package.swift` (slice `swift/macos`): `config` " +
        "is required when `dump_manifests` is set",
        actual.error,
    )

    # A `slices.validate` error is returned as is.
    actual = _collect([_module([_tag(dump_ids = ["_main", "swift-log"], desc_ids = ["_main"])])])
    asserts.equals(
        env,
        "slice `swift/macos`: dump_manifests and desc_manifests have " +
        "different identities; differing: swift-log",
        actual.error,
    )

    return unittest.end(env)

collect_requires_config_test = unittest.make(_collect_requires_config_test)

def _collect_rejects_duplicate_root_configs_test(ctx):
    env = unittest.begin(ctx)

    actual = _collect([_module([_tag(), _tag(dir = "swift/other")])])
    asserts.equals(
        env,
        "slices `swift/macos` and `swift/other` have the same config " +
        "`@@//config:macos`; each slice of the root module needs its own " +
        "config",
        actual.error,
    )

    # Non-root modules may reuse a root config.
    actual = _collect([
        _module([_tag()]),
        _module([_tag(dir = "dep/macos")], is_root = False),
    ])
    asserts.equals(env, None, actual.error)

    return unittest.end(env)

collect_rejects_duplicate_root_configs_test = unittest.make(
    _collect_rejects_duplicate_root_configs_test,
)

def slice_declarations_test_suite():
    return unittest.suite(
        "slice_declarations_tests",
        fresh_slice_lists_all_identities_test,
        missing_dump_marks_stale_and_keeps_names_test,
        changed_manifest_marks_stale_test,
        unlisted_identity_marks_stale_test,
        structurally_bad_manifest_marks_stale_test,
        malformed_pin_is_skipped_test,
        registry_pin_fails_with_2699_test,
        no_resolved_file_means_no_pins_test,
        patch_files_by_identity_test,
        stale_warning_and_merge_entry_test,
        bazel_workspace_root_test,
        collect_builds_slices_in_order_test,
        collect_requires_config_test,
        collect_rejects_duplicate_root_configs_test,
    )
