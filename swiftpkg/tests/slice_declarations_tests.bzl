"""Tests for `slice_declarations` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//swiftpkg/bzlmod:slice_declarations.bzl",
    "slice_declarations",
    "slice_declarations_testing",
)
load("//swiftpkg/internal:slice_messages.bzl", "slice_messages")
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
        is_dev = False,
        netrc = None,
        registries = None,
        make_files_read_only = False):
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
        netrc = netrc,
        registries = registries,
        make_files_read_only = make_files_read_only,
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
    for identity in ev.pkgs:
        asserts.equals(env, "6.0", ev.pkgs[identity].swift_version, identity)

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

def _inconsistent_manifest_lists_mark_stale_test(ctx):
    env = unittest.begin(ctx)

    def _slice(dump_ids, desc_ids):
        return slices.new(
            config = Label("@@//config:macos"),
            swift = Label("@@//app:Package.swift"),
            resolved = Label("@@//swift/macos:Package.resolved"),
            dump_manifests = {i: _cache_label(i, "dump.json") for i in dump_ids},
            desc_manifests = {i: _cache_label(i, "desc.json") for i in desc_ids},
            is_root = True,
            is_dev = False,
        )

    # The dump and desc lists disagree.
    actual = _evaluate(
        _fresh_files(),
        slice = _slice(_ALL_IDS, ["_main", "leaf_pkg", "local_pkg"]),
    )
    asserts.equals(env, None, actual.error)
    ev = actual.result
    asserts.true(env, ev.stale)
    asserts.equals(
        env,
        [
            "slice `swift/macos`: dump_manifests and desc_manifests have " +
            "different identities; differing: swift-log",
        ],
        ev.reasons,
    )
    _assert_stale_pkgs(env, ev, ["leaf_pkg", "local_pkg", "swift-log"])

    # Non-empty lists without `_main`.
    ids = ["leaf_pkg", "local_pkg", "swift-log"]
    actual = _evaluate(_fresh_files(), slice = _slice(ids, ids))
    asserts.equals(env, None, actual.error)
    asserts.true(env, actual.result.stale)
    asserts.equals(
        env,
        ["slice `swift/macos`: dump_manifests is missing the `_main` identity"],
        actual.result.reasons,
    )

    return unittest.end(env)

inconsistent_manifest_lists_mark_stale_test = unittest.make(
    _inconsistent_manifest_lists_mark_stale_test,
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

def _bootstrap_slice_with_unknown_patch_is_stale_test(ctx):
    env = unittest.begin(ctx)

    # `init` wrote empty manifest dicts. A patched `configure_package` whose
    # name matches no identity must not stop evaluation; `cache` has to run.
    patch = Label("@@//patches:unknown.patch")
    actual = _evaluate(
        {"/ws/app/Package.swift": "// MyPkg"},
        slice = _new_slice(identities = []),
        config_pkgs = {"unknown": struct(name = "unknown", patches = [patch])},
    )
    asserts.equals(env, None, actual.error)
    asserts.true(env, actual.result.stale)

    return unittest.end(env)

bootstrap_slice_with_unknown_patch_is_stale_test = unittest.make(
    _bootstrap_slice_with_unknown_patch_is_stale_test,
)

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

# MARK: - declare

_MACOS = "@@//config:macos"
_LINUX = "@@//config:linux"
_WINDOWS = "@@//config:windows"
_LOG_URL = "https://github.com/apple/swift-log"
_PACKAGE_REPOS_LABEL = "@swift_deps_package_repos//:package_repos.json"

def _decl_slice(dir, config, identities, is_root = True, is_dev = False, netrc = None, registries = None, make_files_read_only = False):
    ids = ["_main"] + identities
    return slices.new(
        config = Label(config),
        swift = Label("@@//app:Package.swift"),
        resolved = Label("@@//{}:Package.resolved".format(dir)),
        dump_manifests = {
            i: Label("@@//{}:swift_deps_cache/{}/dump.json".format(dir, i))
            for i in ids
        },
        desc_manifests = {
            i: Label("@@//{}:swift_deps_cache/{}/desc.json".format(dir, i))
            for i in ids
        },
        is_root = is_root,
        is_dev = is_dev,
        netrc = netrc,
        registries = registries,
        make_files_read_only = make_files_read_only,
    )

def _git_dep(identity, revision, name = None):
    return struct(
        identity = identity,
        name = name if name != None else identity,
        source_control = struct(pin = struct(
            location = "https://github.com/apple/" + identity,
            state = struct(revision = revision, version = "1.0.0"),
        )),
        file_system = None,
        registry = None,
    )

def _fresh_entry(dir, identity, revision = "aaa", swift_version = "6.0"):
    dep = _git_dep(identity, revision)
    return struct(
        kind = "source_control",
        pin_key = "{}@{}".format(dep.source_control.pin.location, revision),
        dump_text = "dump-" + revision,
        desc_text = "desc-" + revision,
        dump_label = Label("@@//{}:swift_deps_cache/{}/dump.json".format(dir, identity)),
        desc_label = Label("@@//{}:swift_deps_cache/{}/desc.json".format(dir, identity)),
        local_path = None,
        dep = dep,
        swift_version = swift_version,
    )

def _fresh(
        dir,
        config,
        revisions = {"swift-log": "aaa"},
        direct = None,
        is_root = True,
        is_dev = False,
        swift_version = "6.0",
        netrc = None,
        registries = None,
        make_files_read_only = False,
        extra_pkgs = {}):
    """A fresh evaluated slice. `direct` lists the root's direct deps."""
    if direct == None:
        direct = sorted(revisions.keys())
    pkgs = {
        identity: _fresh_entry(dir, identity, revision, swift_version)
        for identity, revision in revisions.items()
    }
    pkgs.update(extra_pkgs)
    return struct(
        slice = _decl_slice(
            dir,
            config,
            sorted(pkgs.keys()),
            is_root = is_root,
            is_dev = is_dev,
            netrc = netrc,
            registries = registries,
            make_files_read_only = make_files_read_only,
        ),
        stale = False,
        reasons = [],
        pkgs = pkgs,
        pkg_info = struct(dependencies = [pkgs[i].dep for i in direct]),
        module_aliases_by_id = {},
    )

def _stale(dir, config, identities = ["swift-log"], is_root = True):
    return struct(
        slice = _decl_slice(dir, config, identities, is_root = is_root),
        stale = True,
        reasons = ["changed"],
        pkgs = {
            identity: struct(
                kind = "source_control",
                pin_key = "x@" + identity,
                swift_version = None,
            )
            for identity in identities
        },
        pkg_info = None,
        module_aliases_by_id = {},
    )

def _inference_config():
    return struct(
        defaults = {"binary_target_deps": False, "system_sdk_deps": False},
        packages = {},
        matched_names = {},
        available_names = {},
    )

def _config_pkg(name, patches = [], patch_args = [], publicly_expose_all_targets = False):
    return struct(
        name = name,
        build_file = None,
        target_deps = {},
        init_submodules = False,
        recursive_init_submodules = True,
        patch_args = patch_args,
        patch_cmds = [],
        patch_cmds_win = [],
        patch_tool = "",
        patches = patches,
        publicly_expose_all_targets = publicly_expose_all_targets,
    )

def _declare(evaluated, config_pkgs = {}, target_mods_by_repo = {}):
    """Runs `declare` with fake rules.

    Returns:
        A `struct(result, calls, matched, available)`. `calls` is a `dict` of
        rule kind to the `list` of kwargs passed to it.
    """
    calls = {
        kind: []
        for kind in ["git", "local", "aliases", "stale", "tool_repo", "package_repos"]
    }

    def _rule(kind):
        return lambda **kwargs: calls[kind].append(kwargs)

    matched = {}
    available = {}
    result = slice_declarations.declare(
        fake_module_ctx.new(),
        evaluated,
        config_pkgs,
        None,
        target_mods_by_repo,
        matched,
        available,
        _inference_config(),
        package_rules = struct(**{kind: _rule(kind) for kind in calls}),
    )
    return struct(result = result, calls = calls, matched = matched, available = available)

def _swift_version(dir):
    return Label("@@//{}:swift_deps_cache/_main/swift_version.txt".format(dir))

def _identical_declares_one_repo_test(ctx):
    env = unittest.begin(ctx)

    actual = _declare(
        [_fresh("swift/macos", _MACOS), _fresh("swift/linux", _LINUX)],
        target_mods_by_repo = {"swiftpkg_swift_log": []},
    )
    asserts.equals(env, [], actual.calls["aliases"])
    asserts.equals(env, [], actual.calls["stale"])
    asserts.equals(env, [], actual.calls["local"])
    asserts.equals(
        env,
        [{"name": "swift_deps_package_repos", "repo_names": ["swiftpkg_swift_log"]}],
        actual.calls["package_repos"],
    )
    asserts.equals(env, 1, len(actual.calls["git"]))
    kwargs = actual.calls["git"][0]
    asserts.equals(env, "swiftpkg_swift_log", kwargs["name"])
    asserts.equals(env, "swiftpkg_swift_log", kwargs["bazel_package_name"])
    asserts.equals(env, _LOG_URL, kwargs["remote"])
    asserts.equals(env, "aaa", kwargs["commit"])
    asserts.equals(env, "1.0.0", kwargs["version"])
    asserts.equals(
        env,
        Label("@@//swift/macos:swift_deps_cache/swift-log/dump.json"),
        kwargs["dump_manifest"],
    )
    asserts.equals(
        env,
        Label("@@//swift/macos:swift_deps_cache/swift-log/desc.json"),
        kwargs["desc_manifest"],
    )
    asserts.equals(env, _swift_version("swift/macos"), kwargs["swift_version"])
    asserts.equals(env, "swift/macos", kwargs["slice_dir"])
    asserts.equals(env, _PACKAGE_REPOS_LABEL, kwargs["package_repos"])
    asserts.equals(env, {}, kwargs["module_aliases"])
    asserts.equals(env, "", kwargs["dep_module_aliases"])
    asserts.equals(env, False, kwargs["system_sdk_deps"])
    for v1_only in ["env", "env_inherit", "cached_json_directory", "registries", "replace_scm_with_registry"]:
        asserts.false(env, v1_only in kwargs, v1_only)
    asserts.equals(env, {"swiftpkg_swift_log": True}, actual.matched)
    asserts.equals(env, {"swiftpkg_swift_log": True}, actual.available)

    return unittest.end(env)

identical_declares_one_repo_test = unittest.make(_identical_declares_one_repo_test)

def _two_groups_declare_hidden_repos_and_aliases_test(ctx):
    env = unittest.begin(ctx)

    actual = _declare([
        _fresh("swift/macos", _MACOS, {"swift-log": "aaa"}),
        _fresh("swift/linux", _LINUX, {"swift-log": "bbb"}),
        _stale("swift/windows", _WINDOWS),
    ])
    git = actual.calls["git"]
    asserts.equals(
        env,
        ["swiftpkg_swift_log__slice_1", "swiftpkg_swift_log__slice_2"],
        [k["name"] for k in git],
    )
    asserts.equals(env, ["aaa", "bbb"], [k["commit"] for k in git])
    asserts.equals(env, ["swift/macos", "swift/linux"], [k["slice_dir"] for k in git])
    asserts.equals(
        env,
        [_swift_version("swift/macos"), _swift_version("swift/linux")],
        [k["swift_version"] for k in git],
    )
    asserts.equals(
        env,
        [{
            "branches": {
                _MACOS: "swiftpkg_swift_log__slice_1",
                _LINUX: "swiftpkg_swift_log__slice_2",
                _WINDOWS: "",
            },
            "name": "swiftpkg_swift_log",
            "stale_messages": {
                _WINDOWS: slice_messages.stale("swift/windows", _WINDOWS),
            },
        }],
        actual.calls["aliases"],
    )
    asserts.equals(env, [], actual.calls["stale"])

    # Hidden repos are not user-visible.
    asserts.equals(
        env,
        [{"name": "swift_deps_package_repos", "repo_names": ["swiftpkg_swift_log"]}],
        actual.calls["package_repos"],
    )

    return unittest.end(env)

two_groups_declare_hidden_repos_and_aliases_test = unittest.make(
    _two_groups_declare_hidden_repos_and_aliases_test,
)

def _stale_only_declares_stale_repo_test(ctx):
    env = unittest.begin(ctx)

    actual = _declare([
        _fresh("swift/macos", _MACOS, {}),
        _stale("swift/linux", _LINUX, ["swift-nio"]),
    ])
    asserts.equals(env, [], actual.calls["git"])
    asserts.equals(env, [], actual.calls["aliases"])
    asserts.equals(
        env,
        [{
            "message": slice_messages.stale("swift/linux", _LINUX),
            "name": "swiftpkg_swift_nio",
        }],
        actual.calls["stale"],
    )
    asserts.equals(env, {"swiftpkg_swift_nio": True}, actual.available)

    return unittest.end(env)

stale_only_declares_stale_repo_test = unittest.make(
    _stale_only_declares_stale_repo_test,
)

def _swift_package_declared_once_for_two_root_slices_test(ctx):
    env = unittest.begin(ctx)

    patch = Label("@@//patches:log.patch")
    actual = _declare(
        [
            _fresh("swift/macos", _MACOS),
            _fresh("swift/linux", _LINUX),
        ],
        config_pkgs = {
            # The same patch twice is listed once.
            "swift-log": _config_pkg("swift-log", patches = [patch, patch], patch_args = ["-p1"]),
            # The package repo applies only the `swift-log` tag, so the tool
            # does too.
            "swiftpkg_swift_log": _config_pkg(
                "swiftpkg_swift_log",
                patches = [Label("@@//patches:other.patch")],
            ),
            "unknown": _config_pkg("unknown", patches = [Label("@@//patches:x.patch")]),
        },
    )
    tool = actual.calls["tool_repo"]
    asserts.equals(env, 1, len(tool))
    kwargs = tool[0]
    asserts.equals(env, "swift_package", kwargs["name"])
    asserts.equals(env, "app/Package.swift", kwargs["package"])
    asserts.equals(env, "app/Package.swift", kwargs["package_path"])
    asserts.equals(env, "@@//app:Package.swift", kwargs["swift_label"])
    asserts.equals(env, staleness.render_flags(None), kwargs["flags"])
    asserts.equals(
        env,
        [
            {"config": _MACOS, "config_value": _MACOS, "dir": "swift/macos", "package_value": "//swift/macos"},
            {"config": _LINUX, "config_value": _LINUX, "dir": "swift/linux", "package_value": "//swift/linux"},
        ],
        json.decode(kwargs["slices"]),
    )
    asserts.equals(
        env,
        {"swift-log": {"args": ["-p1"], "files": [str(patch)]}},
        json.decode(kwargs["patch_specs"]),
    )
    asserts.equals(env, [patch], kwargs["patch_files"])

    return unittest.end(env)

swift_package_declared_once_for_two_root_slices_test = unittest.make(
    _swift_package_declared_once_for_two_root_slices_test,
)

def _tool_flags_carry_from_package_labels_test(ctx):
    env = unittest.begin(ctx)

    netrc = Label("@@//auth:.netrc")
    registries = Label("@@//:registries.json")
    actual = _declare([
        _fresh("swift/macos", _MACOS, netrc = netrc, registries = registries),
        _fresh("swift/linux", _LINUX, netrc = netrc, registries = registries),
    ])
    tool = actual.calls["tool_repo"]
    asserts.equals(env, 1, len(tool))
    asserts.equals(
        env,
        staleness.render_flags(None, netrc = netrc, registries = registries),
        tool[0]["flags"],
    )
    asserts.true(env, "netrc=auth/.netrc\n" in tool[0]["flags"])
    asserts.true(env, "registries=registries.json\n" in tool[0]["flags"])

    return unittest.end(env)

tool_flags_carry_from_package_labels_test = unittest.make(
    _tool_flags_carry_from_package_labels_test,
)

def _bootstrap_slice_patches_reach_tool_test(ctx):
    env = unittest.begin(ctx)

    # `init` wrote empty manifest dicts, so only the pins name the package.
    # The first cache run must still copy its patch.
    patch = Label("@@//patches:maps.patch")
    bootstrap = struct(
        slice = slices.new(
            config = Label(_MACOS),
            swift = Label("@@//app:Package.swift"),
            resolved = Label("@@//swift/macos:Package.resolved"),
            dump_manifests = {},
            desc_manifests = {},
            is_root = True,
            is_dev = False,
        ),
        stale = True,
        reasons = ["missing cached copy"],
        pkgs = {
            "ios-maps-sdk": struct(
                kind = "source_control",
                pin_key = "x@ios-maps-sdk",
                swift_version = None,
            ),
        },
        pkg_info = None,
        module_aliases_by_id = {},
    )
    actual = _declare(
        [bootstrap],
        config_pkgs = {
            "ios-maps-sdk": _config_pkg("ios-maps-sdk", patches = [patch], patch_args = ["-p1"]),
        },
    )
    kwargs = actual.calls["tool_repo"][0]
    asserts.equals(
        env,
        {"ios-maps-sdk": {"args": ["-p1"], "files": [str(patch)]}},
        json.decode(kwargs["patch_specs"]),
    )
    asserts.equals(env, [patch], kwargs["patch_files"])

    return unittest.end(env)

bootstrap_slice_patches_reach_tool_test = unittest.make(
    _bootstrap_slice_patches_reach_tool_test,
)

def _fresh_slice_missing_identity_gets_missing_message_test(ctx):
    env = unittest.begin(ctx)

    actual = _declare([
        _fresh("swift/macos", _MACOS, {"swift-log": "aaa"}),
        _fresh("swift/linux", _LINUX, {}),
    ])
    asserts.equals(
        env,
        ["swiftpkg_swift_log__slice_1"],
        [k["name"] for k in actual.calls["git"]],
    )
    asserts.equals(
        env,
        [{
            "branches": {
                _MACOS: "swiftpkg_swift_log__slice_1",
                _LINUX: "",
            },
            "name": "swiftpkg_swift_log",
            "stale_messages": {
                _LINUX: slice_messages.missing("swift/linux", _LINUX, "swift-log"),
            },
        }],
        actual.calls["aliases"],
    )

    return unittest.end(env)

fresh_slice_missing_identity_gets_missing_message_test = unittest.make(
    _fresh_slice_missing_identity_gets_missing_message_test,
)

def _direct_deps_split_dev_test(ctx):
    env = unittest.begin(ctx)

    actual = _declare(
        [
            # `swift-collections` and `swift-atomics` are transitive.
            _fresh(
                "swift/macos",
                _MACOS,
                {"swift-atomics": "a", "swift-collections": "c", "swift-log": "l"},
                direct = ["swift-log"],
            ),
            _fresh("swift/dev", _LINUX, {"swift-log": "l", "swift-nio": "n"}, is_dev = True),
        ],
        config_pkgs = {
            "swift-collections": _config_pkg(
                "swift-collections",
                publicly_expose_all_targets = True,
            ),
        },
    )
    asserts.equals(
        env,
        ["swiftpkg_swift_collections", "swiftpkg_swift_log", "swift_package"],
        actual.result.direct,
    )
    asserts.equals(env, ["swiftpkg_swift_nio"], actual.result.direct_dev)

    return unittest.end(env)

direct_deps_split_dev_test = unittest.make(_direct_deps_split_dev_test)

def _identical_requires_same_swift_version_test(ctx):
    env = unittest.begin(ctx)

    # Same pin and manifest bytes, cached with different Swift minors.
    actual = _declare([
        _fresh("swift/macos", _MACOS, swift_version = "6.4"),
        _fresh("swift/linux", _LINUX, swift_version = "6.3"),
    ])
    git = actual.calls["git"]
    asserts.equals(
        env,
        ["swiftpkg_swift_log__slice_1", "swiftpkg_swift_log__slice_2"],
        [k["name"] for k in git],
    )
    asserts.equals(
        env,
        [_swift_version("swift/macos"), _swift_version("swift/linux")],
        [k["swift_version"] for k in git],
    )
    asserts.equals(
        env,
        [{
            "branches": {
                _LINUX: "swiftpkg_swift_log__slice_2",
                _MACOS: "swiftpkg_swift_log__slice_1",
            },
            "name": "swiftpkg_swift_log",
            "stale_messages": {},
        }],
        actual.calls["aliases"],
    )

    return unittest.end(env)

identical_requires_same_swift_version_test = unittest.make(
    _identical_requires_same_swift_version_test,
)

def _identical_ignores_swift_patch_version_test(ctx):
    env = unittest.begin(ctx)

    # Evaluation keeps only `major.minor` of `swift_version.txt`.
    versions = []
    for text in ["6.4.2\n", "6.4.0\n"]:
        files = _fresh_files()
        files[_cache("_main", "swift_version.txt")] = text
        actual = _evaluate(files)
        asserts.equals(env, None, actual.error)
        for identity, pkg in actual.result.pkgs.items():
            asserts.equals(env, "6.4", pkg.swift_version, identity)
        versions.append(actual.result.pkgs["swift-log"].swift_version)

    # Slices cached by 6.4.2 and 6.4.0 with the same bytes are identical.
    actual = _declare([
        _fresh("swift/macos", _MACOS, swift_version = versions[0]),
        _fresh("swift/linux", _LINUX, swift_version = versions[1]),
    ])
    git = actual.calls["git"]
    asserts.equals(env, ["swiftpkg_swift_log"], [k["name"] for k in git])
    asserts.equals(env, [], actual.calls["aliases"])

    return unittest.end(env)

identical_ignores_swift_patch_version_test = unittest.make(
    _identical_ignores_swift_patch_version_test,
)

def _v2_passes_netrc_and_read_only_test(ctx):
    env = unittest.begin(ctx)

    netrc = Label("@@//:.netrc")
    local = struct(
        kind = "local",
        pin_key = "path:local_pkg",
        dump_text = "dump",
        desc_text = "desc",
        dump_label = Label("@@//swift/macos:swift_deps_cache/local_pkg/dump.json"),
        desc_label = Label("@@//swift/macos:swift_deps_cache/local_pkg/desc.json"),
        local_path = "local_pkg",
        dep = struct(
            identity = "local_pkg",
            name = "local_pkg",
            source_control = None,
            file_system = struct(path = "/ws/local_pkg"),
            registry = None,
        ),
        swift_version = "6.0",
    )
    actual = _declare([
        _fresh(
            "swift/macos",
            _MACOS,
            netrc = netrc,
            make_files_read_only = True,
            extra_pkgs = {"local_pkg": local},
        ),
    ])
    git = actual.calls["git"]
    asserts.equals(env, 1, len(git))
    asserts.equals(env, netrc, git[0]["netrc"])
    asserts.equals(env, True, git[0]["make_files_read_only"])

    # `local_swift_package` has neither attribute.
    local_calls = actual.calls["local"]
    asserts.equals(env, 1, len(local_calls))
    asserts.equals(env, "local_pkg", local_calls[0]["path"])
    asserts.false(env, "netrc" in local_calls[0])
    asserts.false(env, "make_files_read_only" in local_calls[0])

    return unittest.end(env)

v2_passes_netrc_and_read_only_test = unittest.make(
    _v2_passes_netrc_and_read_only_test,
)

# MARK: - collect

def _collect_builds_slices_in_order_test(ctx):
    env = unittest.begin(ctx)

    v1 = _tag(config = None, dump_ids = [])
    actual = _collect([
        _module([
            _tag(
                netrc = Label("@@//:.netrc"),
                registries = Label("@@//:registries.json"),
                make_files_read_only = True,
            ),
            v1,
            _tag(dir = "swift/linux", config = Label("@@//config:linux"), is_dev = True),
        ]),
        # A non-root module's v1 tag is not a slice.
        _module([v1], is_root = False),
    ])
    asserts.equals(env, None, actual.error)
    asserts.equals(
        env,
        ["swift/macos", "swift/linux"],
        [s.dir for s in actual.result],
    )
    asserts.equals(env, [True, True], [s.is_root for s in actual.result])
    asserts.equals(env, [False, True], [s.is_dev for s in actual.result])
    asserts.equals(env, [Label("@@//:.netrc"), None], [s.netrc for s in actual.result])
    asserts.equals(
        env,
        [Label("@@//:registries.json"), None],
        [s.registries for s in actual.result],
    )
    asserts.equals(env, [True, False], [s.make_files_read_only for s in actual.result])

    return unittest.end(env)

collect_builds_slices_in_order_test = unittest.make(
    _collect_builds_slices_in_order_test,
)

def _collect_keeps_bootstrap_slice_test(ctx):
    env = unittest.begin(ctx)

    # `init` writes `config` with empty manifest dicts. That is a v2 slice
    # with no cache yet, not a v1 tag.
    actual = _collect([_module([_tag(dump_ids = [])])])
    asserts.equals(env, None, actual.error)
    asserts.equals(env, ["swift/macos"], [s.dir for s in actual.result])
    asserts.equals(env, [], actual.result[0].identities)

    return unittest.end(env)

collect_keeps_bootstrap_slice_test = unittest.make(
    _collect_keeps_bootstrap_slice_test,
)

def _collect_requires_config_test(ctx):
    env = unittest.begin(ctx)

    actual = _collect([_module([_tag(config = None)])])
    asserts.equals(
        env,
        "from_package `@@//:Package.swift` (slice `swift/macos`): `config` " +
        "is required when `config` or `dump_manifests` is set",
        actual.error,
    )

    # Inconsistent manifest lists are left to `evaluate`, which marks the
    # slice stale.
    actual = _collect([_module([_tag(dump_ids = ["_main", "swift-log"], desc_ids = ["_main"])])])
    asserts.equals(env, None, actual.error)
    asserts.equals(env, ["swift/macos"], [s.dir for s in actual.result])

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

    return unittest.end(env)

collect_rejects_duplicate_root_configs_test = unittest.make(
    _collect_rejects_duplicate_root_configs_test,
)

def _non_root_v2_tag_fails_test(ctx):
    env = unittest.begin(ctx)

    actual = _collect([
        _module([_tag()]),
        _module([_tag(dir = "dep/macos")], is_root = False),
    ])
    asserts.equals(
        env,
        "v2 `from_package` slices are only supported in the root module " +
        "for now (module `some_dep`); see " +
        "https://github.com/cgrindel/rules_swift_package_manager/issues/2641",
        actual.error,
    )

    # A bootstrap tag (`config` with empty manifest lists) counts as v2.
    actual = _collect([_module([_tag(dump_ids = [])], is_root = False)])
    asserts.true(env, actual.error != None and "some_dep" in actual.error)

    return unittest.end(env)

non_root_v2_tag_fails_test = unittest.make(_non_root_v2_tag_fails_test)

def slice_declarations_test_suite():
    return unittest.suite(
        "slice_declarations_tests",
        fresh_slice_lists_all_identities_test,
        missing_dump_marks_stale_and_keeps_names_test,
        inconsistent_manifest_lists_mark_stale_test,
        changed_manifest_marks_stale_test,
        unlisted_identity_marks_stale_test,
        structurally_bad_manifest_marks_stale_test,
        malformed_pin_is_skipped_test,
        registry_pin_fails_with_2699_test,
        no_resolved_file_means_no_pins_test,
        patch_files_by_identity_test,
        bootstrap_slice_with_unknown_patch_is_stale_test,
        stale_warning_and_merge_entry_test,
        bazel_workspace_root_test,
        collect_builds_slices_in_order_test,
        collect_keeps_bootstrap_slice_test,
        collect_requires_config_test,
        collect_rejects_duplicate_root_configs_test,
        identical_declares_one_repo_test,
        two_groups_declare_hidden_repos_and_aliases_test,
        stale_only_declares_stale_repo_test,
        swift_package_declared_once_for_two_root_slices_test,
        tool_flags_carry_from_package_labels_test,
        bootstrap_slice_patches_reach_tool_test,
        non_root_v2_tag_fails_test,
        fresh_slice_missing_identity_gets_missing_message_test,
        direct_deps_split_dev_test,
        identical_requires_same_swift_version_test,
        identical_ignores_swift_patch_version_test,
        v2_passes_netrc_and_read_only_test,
    )
