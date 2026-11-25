"""Tests for `staleness` module."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:slices.bzl", "slices")
load(
    "//swiftpkg/internal:staleness.bzl",
    "staleness",
    "staleness_testing",
)

# MARK: - Fake reader

_WS = "/ws"

def _key(path_or_label):
    if type(path_or_label) == "Label":
        if path_or_label.package:
            return "{}/{}/{}".format(
                _WS,
                path_or_label.package,
                path_or_label.name,
            )
        return "{}/{}".format(_WS, path_or_label.name)
    return path_or_label

def _normalize(path):
    parts = []
    for part in path.split("/"):
        if part == "" or part == ".":
            continue
        if part == "..":
            if parts:
                parts.pop()
            continue
        parts.append(part)
    return "/" + "/".join(parts)

def _fake_reader(files):
    """Returns a reader over `files` (a `dict` of absolute path to text).

    The returned `struct` also has a `watched` list that records every
    `watch` call and a `checked` list that records every `exists` call.
    """
    watched = []
    checked = []

    def _exists(path_or_label):
        key = _key(path_or_label)
        checked.append(key)
        if key in files:
            return True
        prefix = key + "/"
        for f in files:
            if f.startswith(prefix):
                return True
        return False

    def _read(path_or_label):
        return files.get(_key(path_or_label))

    def _readdir(path):
        prefix = _key(path) + "/"
        names = {}
        for f in files:
            if f.startswith(prefix):
                names[f[len(prefix):].split("/")[0]] = True
        return sorted(names.keys())

    def _watch(path):
        watched.append(_key(path))

    def _dirname(path_or_label):
        key = _key(path_or_label)
        return key[:key.rfind("/")]

    def _join(dir, rel):
        if rel.startswith("/"):
            return _normalize(rel)
        return _normalize(dir + "/" + rel)

    return struct(
        exists = _exists,
        read = _read,
        readdir = _readdir,
        watch = _watch,
        dirname = _dirname,
        join = _join,
        watched = watched,
        checked = checked,
    )

def _assert_checked_paths_watched(env, reader):
    watched = {w: True for w in reader.watched}
    unwatched = [c for c in reader.checked if c not in watched]
    asserts.equals(env, [], unwatched)

# MARK: - Fixtures

_SLICE_DIR = "swift/macos"
_CACHE = "{}/{}/swift_deps_cache".format(_WS, _SLICE_DIR)

_DEFAULT_FLAGS = """\
dependency_caching=true
manifest_cache=shared
manifest_caching=true
replace_scm_with_registry=false
use_registry_identity_for_scm=false
"""

def _new_slice(
        identities = ["_main", "swift-log"],
        netrc = None,
        registries = None):
    return slices.new(
        config = Label("@@//config:macos"),
        swift = Label("@@//:Package.swift"),
        resolved = Label("@@//swift/macos:Package.resolved"),
        dump_manifests = {
            i: Label("@@//swift/macos:swift_deps_cache/{}/dump.json".format(i))
            for i in identities
        },
        desc_manifests = {
            i: Label("@@//swift/macos:swift_deps_cache/{}/desc.json".format(i))
            for i in identities
        },
        is_root = True,
        is_dev = False,
        netrc = netrc,
        registries = registries,
    )

def _fresh_files():
    return {
        _WS + "/Package.swift": "// root",
        _WS + "/Package@swift-5.9.swift": "// root 5.9",
        _WS + "/swift/macos/Package.resolved": "{pins}",
        _CACHE + "/_main/Package.swift.cached": "// root",
        _CACHE + "/_main/Package@swift-5.9.swift.cached": "// root 5.9",
        _CACHE + "/_main/Package.resolved.cached": "{pins}",
        _CACHE + "/_main/flags.cached": _DEFAULT_FLAGS,
        _CACHE + "/_main/swift_version.txt": "6.1\n",
        _CACHE + "/_main/dump.json": "{}",
        _CACHE + "/_main/desc.json": "{}",
        _CACHE + "/swift-log/dump.json": "{}",
        _CACHE + "/swift-log/desc.json": "{}",
    }

def _collect(files, slice = None, config = None, patches = {}):
    reader = _fake_reader(files)
    inputs = staleness_testing.collect_with_reader(
        reader,
        slice or _new_slice(),
        config,
        patches,
    )
    return reader, inputs

# MARK: - Tests

def _fresh_test(ctx):
    env = unittest.begin(ctx)

    reader, inputs = _collect(_fresh_files())
    _assert_checked_paths_watched(env, reader)
    asserts.equals(
        env,
        [
            "_main/Package.swift.cached",
            "_main/Package@swift-5.9.swift.cached",
            "_main/Package.resolved.cached",
            "_main/flags.cached",
            "_main/swift_version.txt",
            "_main/dump.json",
            "_main/desc.json",
            "swift-log/dump.json",
            "swift-log/desc.json",
        ],
        [i.name for i in inputs],
    )
    result = staleness.evaluate(inputs)
    asserts.false(env, result.stale)
    asserts.equals(env, [], result.reasons)

    return unittest.end(env)

fresh_test = unittest.make(_fresh_test)

def _missing_manifest_is_stale_test(ctx):
    env = unittest.begin(ctx)

    files = _fresh_files()
    files.pop(_CACHE + "/swift-log/dump.json")
    _, inputs = _collect(files)
    result = staleness.evaluate(inputs)
    asserts.true(env, result.stale)
    asserts.equals(
        env,
        ["swift-log/dump.json: missing cached copy"],
        result.reasons,
    )

    return unittest.end(env)

missing_manifest_is_stale_test = unittest.make(
    _missing_manifest_is_stale_test,
)

def _malformed_manifest_is_stale_test(ctx):
    env = unittest.begin(ctx)

    files = _fresh_files()
    files[_CACHE + "/swift-log/dump.json"] = """\
<<<<<<< HEAD
{}
=======
{"name": "x"}
>>>>>>> other
"""
    _, inputs = _collect(files)
    result = staleness.evaluate(inputs)
    asserts.true(env, result.stale)
    asserts.equals(
        env,
        ["swift-log/dump.json: not valid JSON"],
        result.reasons,
    )

    return unittest.end(env)

malformed_manifest_is_stale_test = unittest.make(
    _malformed_manifest_is_stale_test,
)

def _missing_swift_version_is_stale_test(ctx):
    env = unittest.begin(ctx)

    files = _fresh_files()
    files.pop(_CACHE + "/_main/swift_version.txt")
    reader, inputs = _collect(files)
    _assert_checked_paths_watched(env, reader)
    asserts.true(env, _CACHE + "/_main/swift_version.txt" in reader.watched)
    result = staleness.evaluate(inputs)
    asserts.true(env, result.stale)
    asserts.equals(
        env,
        ["_main/swift_version.txt: missing cached copy"],
        result.reasons,
    )

    return unittest.end(env)

missing_swift_version_is_stale_test = unittest.make(
    _missing_swift_version_is_stale_test,
)

def _changed_package_swift_test(ctx):
    env = unittest.begin(ctx)

    files = _fresh_files()
    files[_WS + "/Package.swift"] = "// root, edited"
    files.pop(_WS + "/Package@swift-5.9.swift")
    files[_WS + "/Package@swift-6.0.swift"] = "// root 6.0"
    _, inputs = _collect(files)
    result = staleness.evaluate(inputs)
    asserts.true(env, result.stale)
    asserts.equals(
        env,
        [
            "_main/Package.swift.cached: differs from cached copy",
            "_main/Package@swift-6.0.swift.cached: missing cached copy",
            "_main/Package@swift-5.9.swift.cached: missing live file",
        ],
        result.reasons,
    )

    return unittest.end(env)

changed_package_swift_test = unittest.make(_changed_package_swift_test)

def _evaluate_reasons_test(ctx):
    env = unittest.begin(ctx)

    result = staleness.evaluate([
        struct(name = "a", live = "x", cached = "x"),
        struct(name = "b", live = None, cached = "x"),
        struct(name = "c", live = "x", cached = None),
        struct(name = "d", live = "x", cached = "y"),
    ])
    asserts.true(env, result.stale)
    asserts.equals(
        env,
        [
            "b: missing live file",
            "c: missing cached copy",
            "d: differs from cached copy",
        ],
        result.reasons,
    )

    return unittest.end(env)

evaluate_reasons_test = unittest.make(_evaluate_reasons_test)

def _resolved_absent_on_both_sides_is_not_an_input_test(ctx):
    env = unittest.begin(ctx)

    files = _fresh_files()
    files.pop(_WS + "/swift/macos/Package.resolved")
    files.pop(_CACHE + "/_main/Package.resolved.cached")
    _, inputs = _collect(files)
    names = [i.name for i in inputs]
    asserts.false(env, "_main/Package.resolved.cached" in names)
    asserts.false(env, staleness.evaluate(inputs).stale)

    # Only one side missing is stale.
    files.pop(_CACHE + "/_main/flags.cached")
    files[_WS + "/swift/macos/Package.resolved"] = "{pins}"
    _, inputs = _collect(files)
    asserts.equals(
        env,
        [
            "_main/Package.resolved.cached: missing cached copy",
            "_main/flags.cached: missing cached copy",
        ],
        staleness.evaluate(inputs).reasons,
    )

    return unittest.end(env)

resolved_absent_on_both_sides_is_not_an_input_test = unittest.make(
    _resolved_absent_on_both_sides_is_not_an_input_test,
)

def _registries_and_patches_test(ctx):
    env = unittest.begin(ctx)

    files = _fresh_files()
    files[_WS + "/registries.json"] = "{reg}"
    files[_CACHE + "/_main/registries.json.cached"] = "{reg}"
    files[_WS + "/patches/log.patch"] = "patch v2"
    files[_CACHE + "/swift-log/patches/log.patch"] = "patch v1"
    registries = Label("@@//:registries.json")
    files[_CACHE + "/_main/flags.cached"] = staleness.render_flags(
        None,
        registries = registries,
    )
    _, inputs = _collect(
        files,
        slice = _new_slice(registries = registries),
        patches = {"swift-log": [Label("@@//patches:log.patch")]},
    )
    names = [i.name for i in inputs]
    asserts.true(env, "_main/registries.json.cached" in names)
    asserts.equals(
        env,
        ["swift-log/patches/log.patch: differs from cached copy"],
        staleness.evaluate(inputs).reasons,
    )

    # A cached registries copy with no configured registries is stale.
    files[_CACHE + "/_main/flags.cached"] = _DEFAULT_FLAGS
    _, inputs = _collect(files)
    asserts.equals(
        env,
        ["_main/registries.json.cached: missing live file"],
        staleness.evaluate(inputs).reasons,
    )

    return unittest.end(env)

registries_and_patches_test = unittest.make(_registries_and_patches_test)

def _local_packages_discovered_to_fixed_point_test(ctx):
    env = unittest.begin(ctx)

    files = _fresh_files()

    # Root -> ../shared/Foo -> ../Bar -> ../Foo (a cycle) and -> the root.
    files[_CACHE + "/_main/desc.json"] = json.encode({
        "dependencies": [
            {"identity": "swift-log", "type": "sourceControl"},
            {"path": "./shared/Foo", "type": "fileSystem"},
        ],
    })
    files[_CACHE + "/foo/desc.json"] = json.encode({
        "dependencies": [{"path": "../Bar", "type": "fileSystem"}],
    })
    files[_CACHE + "/bar/desc.json"] = json.encode({
        "dependencies": [
            {"path": "../Foo", "type": "fileSystem"},
            {"path": "../..", "type": "fileSystem"},
        ],
    })
    files[_WS + "/shared/Foo/Package.swift"] = "// foo"
    files[_WS + "/shared/Foo/Package@swift-6.0.swift"] = "// foo 6.0"
    files[_CACHE + "/foo/Package.swift.cached"] = "// foo"
    files[_CACHE + "/foo/Package@swift-6.0.swift.cached"] = "// foo 6.0"
    files[_WS + "/shared/Bar/Package.swift"] = "// bar, edited"
    files[_CACHE + "/bar/Package.swift.cached"] = "// bar"
    for i in ["foo", "bar"]:
        files[_CACHE + "/{}/dump.json".format(i)] = "{}"
    slice = _new_slice(identities = ["_main", "bar", "foo", "swift-log"])

    reader, inputs = _collect(files, slice = slice)
    names = [i.name for i in inputs]
    asserts.equals(
        env,
        [
            "_main/Package.swift.cached",
            "_main/Package@swift-5.9.swift.cached",
            "_main/Package.resolved.cached",
            "_main/flags.cached",
            "_main/swift_version.txt",
            "foo/Package.swift.cached",
            "foo/Package@swift-6.0.swift.cached",
            "bar/Package.swift.cached",
        ],
        names[:8],
    )
    asserts.equals(
        env,
        ["bar/Package.swift.cached: differs from cached copy"],
        staleness.evaluate(inputs).reasons,
    )
    _assert_checked_paths_watched(env, reader)
    for path in [
        _WS,
        _WS + "/Package@swift-5.9.swift",
        _WS + "/shared/Foo",
        _WS + "/shared/Foo/Package.swift",
        _WS + "/shared/Foo/Package@swift-6.0.swift",
        _WS + "/shared/Bar",
        _WS + "/shared/Bar/Package.swift",
        _CACHE + "/bar/dump.json",
    ]:
        asserts.true(env, path in reader.watched, path)

    return unittest.end(env)

local_packages_discovered_to_fixed_point_test = unittest.make(
    _local_packages_discovered_to_fixed_point_test,
)

# MARK: - render_flags

def _new_config(
        cache_path = ".cache",
        config_path = ".config",
        security_path = ".security",
        dependency_caching = True,
        manifest_cache = "shared",
        manifest_caching = True,
        replace_scm_with_registry = False,
        use_registry_identity_for_scm = False):
    return struct(
        cache_path = cache_path,
        config_path = config_path,
        security_path = security_path,
        dependency_caching = dependency_caching,
        manifest_cache = manifest_cache,
        manifest_caching = manifest_caching,
        replace_scm_with_registry = replace_scm_with_registry,
        use_registry_identity_for_scm = use_registry_identity_for_scm,
    )

# Shared with `SwiftPMFlagsTests.testNormalizedIsSortedAndStable` in
# `tools/swift_deps_tool/Tests/SwiftPMFlagsTests.swift`. Keep them identical.
_TOOL_FIXTURE = """\
cache_path=.spm/cache
dependency_caching=false
manifest_cache=local
manifest_caching=true
netrc=auth/.netrc
replace_scm_with_registry=false
use_registry_identity_for_scm=true
"""

def _render_flags_matches_tool_fixture_test(ctx):
    env = unittest.begin(ctx)

    config = _new_config(
        cache_path = ".spm/cache",
        dependency_caching = False,
        manifest_cache = "local",
        use_registry_identity_for_scm = True,
    )
    asserts.equals(
        env,
        _TOOL_FIXTURE,
        staleness.render_flags(config, netrc = Label("@@//auth:.netrc")),
    )

    return unittest.end(env)

render_flags_matches_tool_fixture_test = unittest.make(
    _render_flags_matches_tool_fixture_test,
)

def _render_flags_defaults_test(ctx):
    env = unittest.begin(ctx)

    # The hard-coded defaults must match `swift_package_tool_attrs.bzl`.
    asserts.equals(
        env,
        {
            "cache_path": ".cache",
            "config_path": ".config",
            "dependency_caching": True,
            "manifest_cache": "shared",
            "manifest_caching": True,
            "replace_scm_with_registry": False,
            "security_path": ".security",
            "use_registry_identity_for_scm": False,
        },
        staleness_testing.defaults,
    )
    asserts.equals(env, _DEFAULT_FLAGS, staleness.render_flags(None))
    asserts.equals(env, _DEFAULT_FLAGS, staleness.render_flags(_new_config()))
    asserts.equals(
        env,
        "config_path=cfg\n" + _DEFAULT_FLAGS.replace(
            "use_registry",
            "security_path=sec\nuse_registry",
        ),
        staleness.render_flags(_new_config(
            config_path = "cfg",
            security_path = "sec",
        )),
    )
    asserts.equals(
        env,
        _DEFAULT_FLAGS.replace(
            "replace_scm_with_registry",
            "registries=reg/registries.json\nreplace_scm_with_registry",
        ),
        staleness.render_flags(
            _new_config(),
            registries = Label("@@//reg:registries.json"),
        ),
    )

    return unittest.end(env)

render_flags_defaults_test = unittest.make(_render_flags_defaults_test)

def _render_flags_root_package_labels_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        _DEFAULT_FLAGS.replace(
            "replace_scm_with_registry",
            "registries=registries.json\nreplace_scm_with_registry",
        ).replace(
            "manifest_caching=true\n",
            "manifest_caching=true\nnetrc=.netrc\n",
        ),
        staleness.render_flags(
            _new_config(),
            netrc = Label("@@//:.netrc"),
            registries = Label("@@//:registries.json"),
        ),
    )

    return unittest.end(env)

render_flags_root_package_labels_test = unittest.make(
    _render_flags_root_package_labels_test,
)

def _render_flags_from_package_labels_test(ctx):
    env = unittest.begin(ctx)

    # A `configure_swift_package` tag has no `netrc` or `registries`
    # attribute; those live on `from_package` and are passed explicitly.
    config = struct(
        cache_path = ".cache",
        config_path = ".config",
        security_path = ".security",
        dependency_caching = False,
        manifest_cache = "shared",
        manifest_caching = True,
        replace_scm_with_registry = False,
        use_registry_identity_for_scm = False,
    )
    netrc = Label("@@//auth:.netrc")
    registries = Label("@@//:registries.json")
    expected = """\
dependency_caching=false
manifest_cache=shared
manifest_caching=true
netrc=auth/.netrc
registries=registries.json
replace_scm_with_registry=false
use_registry_identity_for_scm=false
"""
    asserts.equals(
        env,
        expected,
        staleness.render_flags(
            config,
            netrc = netrc,
            registries = registries,
        ),
    )

    # `collect` reads the labels from the slice: the same flags are fresh,
    # and the registries file is an input.
    slice = _new_slice(netrc = netrc, registries = registries)
    files = _fresh_files()
    files[_WS + "/registries.json"] = "{reg}"
    files[_CACHE + "/_main/registries.json.cached"] = "{reg}"
    files[_CACHE + "/_main/flags.cached"] = expected
    _, inputs = _collect(files, slice = slice, config = config)
    asserts.equals(env, [], staleness.evaluate(inputs).reasons)
    asserts.true(
        env,
        "_main/registries.json.cached" in [i.name for i in inputs],
    )

    # Flags cached without the labels are stale.
    files[_CACHE + "/_main/flags.cached"] = staleness.render_flags(config)
    _, inputs = _collect(files, slice = slice, config = config)
    asserts.equals(
        env,
        ["_main/flags.cached: differs from cached copy"],
        staleness.evaluate(inputs).reasons,
    )

    return unittest.end(env)

render_flags_from_package_labels_test = unittest.make(
    _render_flags_from_package_labels_test,
)

def staleness_test_suite(name = "staleness_tests"):
    return unittest.suite(
        name,
        fresh_test,
        missing_manifest_is_stale_test,
        malformed_manifest_is_stale_test,
        missing_swift_version_is_stale_test,
        changed_package_swift_test,
        evaluate_reasons_test,
        resolved_absent_on_both_sides_is_not_an_input_test,
        registries_and_patches_test,
        local_packages_discovered_to_fixed_point_test,
        render_flags_matches_tool_fixture_test,
        render_flags_defaults_test,
        render_flags_root_package_labels_test,
        render_flags_from_package_labels_test,
    )
