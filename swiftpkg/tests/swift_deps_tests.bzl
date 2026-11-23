"""Tests for the `swift_deps` bzlmod extension helpers."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/bzlmod:swift_deps.bzl", "swift_deps_test_utils")

_target = "@swiftpkg_foo//:Bar.rspm.__impl"

def _new_tags(**kwargs):
    """Create the tags struct for a fake Bazel module.

    Args:
        **kwargs: The target modification tags, keyed by tag class name. Every
            tag class that is not specified is empty.

    Returns:
        A `struct` with a `list` for every target modification tag class.
    """
    tags = {
        tag_class: []
        for tag_class in swift_deps_test_utils.bazel_target_mod_tag_classes
    }
    for (tag_class, value) in kwargs.items():
        if tag_class not in tags:
            fail("Unrecognized tag class '{}'.".format(tag_class))
        tags[tag_class] = value
    return struct(**tags)

def _new_module_ctx(modules):
    return struct(modules = modules)

def _bazel_target_mods_by_repo_test(ctx):
    env = unittest.begin(ctx)

    # No tags anywhere.
    actual = swift_deps_test_utils.bazel_target_mods_by_repo(
        _new_module_ctx([
            struct(is_root = True, name = "my_app", tags = _new_tags()),
            struct(is_root = False, name = "some_dep", tags = _new_tags()),
        ]),
    )
    asserts.equals(env, {}, actual)

    # Tags from the root module are collected and routed by repository name. A
    # non-root module without these tags is simply skipped.
    actual = swift_deps_test_utils.bazel_target_mods_by_repo(
        _new_module_ctx([
            struct(
                is_root = True,
                name = "my_app",
                tags = _new_tags(
                    bazel_target_set_bool = [struct(
                        target = "@swiftpkg_foo//:Bar.rspm.__impl",
                        attr = "alwayslink",
                        value = False,
                    )],
                    bazel_target_set_select_int_dict = [struct(
                        target = "@swiftpkg_foo//:Bar.rspm.__impl",
                        attr = "shard_count",
                        values = {"//:release_build": "4"},
                    )],
                    bazel_target_add = [struct(
                        target = "@swiftpkg_baz//:Qux.rspm.__impl",
                        attr = "copts",
                        values = ["-DBAZ"],
                    )],
                    bazel_target_add_select = [struct(
                        target = "@swiftpkg_foo//:Bar.rspm.__impl",
                        attr = "copts",
                        values = {"//:release_build": ["-O2"]},
                    )],
                ),
            ),
            struct(is_root = False, name = "some_dep", tags = _new_tags()),
        ]),
    )
    asserts.equals(
        env,
        ["swiftpkg_baz", "swiftpkg_foo"],
        sorted(actual.keys()),
    )
    asserts.equals(
        env,
        [
            {
                "attr": "alwayslink",
                "target": "Bar.rspm.__impl",
                "value": False,
                "verb": "set",
            },
            {
                "attr": "shard_count",
                "target": "Bar.rspm.__impl",
                "values": {"@@//:release_build": 4},
                "verb": "set_select",
            },
            {
                "attr": "copts",
                "target": "Bar.rspm.__impl",
                "values": {"@@//:release_build": ["-O2"]},
                "verb": "add_select",
            },
        ],
        actual["swiftpkg_foo"],
    )
    asserts.equals(
        env,
        [{
            "attr": "copts",
            "target": "Qux.rspm.__impl",
            "values": ["-DBAZ"],
            "verb": "add",
        }],
        actual["swiftpkg_baz"],
    )

    return unittest.end(env)

bazel_target_mods_by_repo_test = unittest.make(_bazel_target_mods_by_repo_test)

def _non_root_target_mods_error_test(ctx):
    env = unittest.begin(ctx)

    # A non-root module with no target modification tags is fine.
    asserts.equals(
        env,
        None,
        swift_deps_test_utils.non_root_target_mods_error(
            "some_dep",
            [
                struct(tag_class = "bazel_target_set_bool", verb = "set", tags = []),
                struct(tag_class = "bazel_target_add", verb = "add", tags = []),
            ],
        ),
    )

    error = swift_deps_test_utils.non_root_target_mods_error(
        "some_dep",
        [
            struct(tag_class = "bazel_target_set_bool", verb = "set", tags = []),
            struct(
                tag_class = "bazel_target_set_select_bool_dict",
                verb = "set_select",
                tags = [struct()],
            ),
            struct(
                tag_class = "bazel_target_add",
                verb = "add",
                tags = [struct()],
            ),
            struct(
                tag_class = "bazel_target_add_select",
                verb = "add_select",
                tags = [],
            ),
        ],
    )
    asserts.true(env, error != None, "Expected an error.")
    asserts.true(
        env,
        error.find("some_dep") > -1,
        "Expected the error to name the offending module.",
    )
    asserts.true(
        env,
        error.find("bazel_target_set_select_bool_dict, bazel_target_add") > -1,
        "Expected the error to list the declared tags.",
    )

    return unittest.end(env)

non_root_target_mods_error_test = unittest.make(_non_root_target_mods_error_test)

def _build_file_conflict_error_test(ctx):
    env = unittest.begin(ctx)

    mods = "[{\"verb\": \"add\"}]"

    # Only the combination of a `build_file` override and target modifications
    # is a conflict.
    for t in [
        struct(msg = "no build file, no mods", build_file = None, mods = ""),
        struct(msg = "no build file, mods", build_file = None, mods = mods),
        struct(
            msg = "build file, no mods",
            build_file = "//:my.BUILD.bazel",
            mods = "",
        ),
    ]:
        asserts.equals(
            env,
            None,
            swift_deps_test_utils.build_file_conflict_error(
                "swift-log",
                t.build_file,
                t.mods,
            ),
            t.msg,
        )

    error = swift_deps_test_utils.build_file_conflict_error(
        "swift-log",
        "//:my.BUILD.bazel",
        mods,
    )
    asserts.true(env, error != None, "Expected an error.")
    asserts.true(
        env,
        error.find("swift-log") > -1,
        "Expected the error to name the package.",
    )
    asserts.true(
        env,
        error.find("build_file") > -1,
        "Expected the error to mention the `build_file` override.",
    )

    return unittest.end(env)

build_file_conflict_error_test = unittest.make(_build_file_conflict_error_test)

def _branch_values_test(ctx):
    env = unittest.begin(ctx)

    # The `bool_dict` and `int_dict` `select()` tags take `string` values that
    # are converted to their Starlark type.
    successes = [
        struct(
            msg = "bool",
            tag_class = "bazel_target_set_select_bool_dict",
            branch_type = "bool",
            values = {"//:a": "True", "//conditions:default": "False"},
            exp = {"//:a": True, "//conditions:default": False},
        ),
        struct(
            msg = "int",
            tag_class = "bazel_target_set_select_int_dict",
            branch_type = "int",
            values = {"//:a": "4", "//:b": "-1", "//conditions:default": "0"},
            exp = {"//:a": 4, "//:b": -1, "//conditions:default": 0},
        ),
    ]
    for t in successes:
        actual = swift_deps_test_utils.branch_values(
            t.tag_class,
            t.branch_type,
            struct(target = _target, attr = "some_attr", values = t.values),
        )
        asserts.equals(env, None, actual.error, t.msg)
        asserts.equals(env, t.exp, actual.values, t.msg)

    # Anything else fails with an error that names the target, the attribute,
    # the condition and the offending value.
    failures = [
        struct(
            msg = "lowercase true is not a Starlark bool",
            tag_class = "bazel_target_set_select_bool_dict",
            branch_type = "bool",
            value = "true",
        ),
        struct(
            msg = "non-bool",
            tag_class = "bazel_target_set_select_bool_dict",
            branch_type = "bool",
            value = "yes",
        ),
        struct(
            msg = "empty bool",
            tag_class = "bazel_target_set_select_bool_dict",
            branch_type = "bool",
            value = "",
        ),
        struct(
            msg = "float is not an int",
            tag_class = "bazel_target_set_select_int_dict",
            branch_type = "int",
            value = "1.5",
        ),
        struct(
            msg = "lone dash is not an int",
            tag_class = "bazel_target_set_select_int_dict",
            branch_type = "int",
            value = "-",
        ),
        struct(
            msg = "non-int",
            tag_class = "bazel_target_set_select_int_dict",
            branch_type = "int",
            value = "-DFOO",
        ),
    ]
    for t in failures:
        actual = swift_deps_test_utils.branch_values(
            t.tag_class,
            t.branch_type,
            struct(
                target = _target,
                attr = "some_attr",
                values = {"//:a": t.value},
            ),
        )
        asserts.equals(env, None, actual.values, t.msg)
        asserts.true(
            env,
            actual.error != None,
            "Expected an error for {}.".format(t.msg),
        )
        for expected in [t.tag_class, _target, "some_attr", "//:a", t.value]:
            asserts.true(
                env,
                actual.error.find(expected) > -1,
                "Expected the error to mention '{expected}' for {msg}.".format(
                    expected = expected,
                    msg = t.msg,
                ),
            )

    return unittest.end(env)

branch_values_test = unittest.make(_branch_values_test)

def _inference_module(root = True, defaults = [], packages = []):
    return struct(
        is_root = root,
        name = "app" if root else "dependency",
        tags = struct(configure_explicit_modules = defaults, configure_package = packages),
    )

def _inference_package(name = "foo", sdk = "inherit", binary = "inherit", **kwargs):
    return struct(name = name, system_sdk_deps = sdk, binary_target_deps = binary, **kwargs)

def _inference_configuration_test(ctx):
    env = unittest.begin(ctx)
    collect = swift_deps_test_utils.inference_configuration
    resolve = swift_deps_test_utils.inference_settings
    config = collect([_inference_module(), _inference_module(root = False)])
    asserts.equals(env, None, config.error)
    asserts.equals(env, {"binary_target_deps": False, "system_sdk_deps": False}, resolve(config, "foo", "swiftpkg_foo"))

    # Exercise every combination of independent defaults and tri-state overrides.
    for sdk_default in [False, True]:
        for binary_default in [False, True]:
            for sdk in ["inherit", "on", "off"]:
                for binary in ["inherit", "on", "off"]:
                    config = collect([_inference_module(
                        defaults = [struct(system_sdk_deps = sdk_default, binary_target_deps = binary_default)],
                        packages = [_inference_package(sdk = sdk, binary = binary)],
                    )])
                    asserts.equals(env, None, config.error)
                    asserts.equals(env, {
                        "binary_target_deps": binary_default if binary == "inherit" else binary == "on",
                        "system_sdk_deps": sdk_default if sdk == "inherit" else sdk == "on",
                    }, resolve(config, "foo", "swiftpkg_foo"))
                    asserts.equals(env, config.defaults, resolve(config, "other", "swiftpkg_other"))

    # Repository-name aliases work, and dependency-module legacy configuration
    # cannot overwrite the root's inference policy, regardless of module order.
    root = _inference_module(packages = [_inference_package(name = "swiftpkg_foo", sdk = "on")])
    dep = _inference_module(root = False, packages = [_inference_package()])
    for modules in [[root, dep], [dep, root]]:
        config = collect(modules)
        asserts.equals(env, True, resolve(config, "foo", "swiftpkg_foo")["system_sdk_deps"])

    # A dependency-name override takes precedence over a repository-name alias.
    config = collect([_inference_module(packages = [
        _inference_package(name = "swiftpkg_foo", sdk = "on", binary = "on"),
        _inference_package(name = "foo", sdk = "off"),
    ])])
    asserts.equals(env, {"binary_target_deps": False, "system_sdk_deps": False}, resolve(config, "foo", "swiftpkg_foo"))
    return unittest.end(env)

inference_configuration_test = unittest.make(_inference_configuration_test)

def _inference_validation_test(ctx):
    env = unittest.begin(ctx)
    defaults = struct(system_sdk_deps = True, binary_target_deps = False)
    for modules, expected in [
        ([_inference_module(root = False, defaults = [defaults])], "Only the root module"),
        ([_inference_module(root = False, packages = [_inference_package(sdk = "off")])], "Only the root module"),
        ([_inference_module(root = False, packages = [_inference_package(binary = "on")])], "Only the root module"),
        ([_inference_module(defaults = [defaults, defaults])], "at most one"),
        ([_inference_module(packages = [_inference_package(sdk = "on"), _inference_package(sdk = "off")])], "Duplicate"),
    ]:
        result = swift_deps_test_utils.inference_configuration(modules)
        asserts.true(env, expected in result.error, result.error)
    return unittest.end(env)

inference_validation_test = unittest.make(_inference_validation_test)

def _duplicate_package_configuration_test(ctx):
    env = unittest.begin(ctx)
    legacy = _inference_package(
        build_file = "//:custom.BUILD",
        patches = ["//:fix.patch"],
        target_deps = {"Foo": [":Bar"]},
    )
    inference = _inference_package(sdk = "on")
    for packages in [[legacy, inference], [inference, legacy], [legacy, legacy]]:
        config = swift_deps_test_utils.inference_configuration([
            _inference_module(packages = packages),
        ])
        asserts.true(env, "Duplicate configure_package" in config.error)
        asserts.true(env, "foo" in config.error)

    # Inference fields can coexist with legacy fields on a single tag.
    config = swift_deps_test_utils.inference_configuration([
        _inference_module(packages = [_inference_package(
            sdk = "on",
            build_file = legacy.build_file,
            patches = legacy.patches,
            target_deps = legacy.target_deps,
        )]),
    ])
    asserts.equals(env, None, config.error)
    asserts.true(env, swift_deps_test_utils.inference_settings(config, "foo", "swiftpkg_foo")["system_sdk_deps"])
    return unittest.end(env)

duplicate_package_configuration_test = unittest.make(_duplicate_package_configuration_test)

def _unknown_inference_packages_test(ctx):
    env = unittest.begin(ctx)
    collect = swift_deps_test_utils.inference_configuration
    record = swift_deps_test_utils.record_inference_packages
    error = swift_deps_test_utils.unknown_inference_packages_error
    config = collect([_inference_module(packages = [
        _inference_package(name = "swift-log", sdk = "on"),
        _inference_package(name = "swiftpkg_swift_log", binary = "off"),
        _inference_package(name = "swift-lgo", sdk = "off"),
    ])])

    # Names match even before a dependency has a resolved pin. Both aliases
    # count, including the lower-priority repository-name override.
    record(config, [struct(name = "swift-log", identity = "swift-log")])
    asserts.equals(env, ["swift-log", "swiftpkg_swift_log"], sorted(config.matched_names))
    asserts.equals(env, "Dependency inference overrides were declared for unknown packages: swift-lgo. Available package names and repositories are: swift-log, swiftpkg_swift_log.", error(config))

    # Discovery accumulates across multiple from_package declarations.
    record(config, [struct(name = "swift-lgo", identity = "swift-lgo")])
    asserts.equals(env, None, error(config))
    config = collect([_inference_module(packages = [_inference_package(sdk = "on")])])
    asserts.true(env, "unknown packages: foo" in error(config))
    config = collect([_inference_module(packages = [_inference_package()])])
    asserts.equals(env, None, error(config))
    return unittest.end(env)

unknown_inference_packages_test = unittest.make(_unknown_inference_packages_test)

def _inference_repository_routing_test(ctx):
    env = unittest.begin(ctx)
    calls = []

    def _capture(**kwargs):
        calls.append(kwargs)

    from_package = struct(
        env = {},
        env_inherit = [],
        registries = {},
        resolved = None,
        make_files_read_only = False,
        netrc = None,
    )
    for kind in ["git", "local", "registry"]:
        for sdk, binary in [(False, False), (True, False), (False, True), (True, True)]:
            settings = {"binary_target_deps": binary, "system_sdk_deps": sdk}
            dep = struct(
                name = "foo",
                identity = "foo",
                source_control = struct(pin = struct(
                    state = struct(revision = "abc", version = "1.0.0"),
                    location = "https://example.com/foo.git",
                )) if kind == "git" else None,
                file_system = struct(path = "/workspace/foo") if kind == "local" else None,
                registry = struct(pin = struct(identity = "example.foo", state = struct(version = "1.0.0"))) if kind == "registry" else None,
            )
            swift_deps_test_utils.declare_pkg_from_dependency(
                dep,
                None,
                from_package,
                None,
                None,
                {},
                {},
                "",
                "/workspace",
                "",
                None,
                settings,
                package_rules = struct(git = _capture, local = _capture, registry = _capture),
            )
            asserts.equals(env, sdk, calls[-1]["system_sdk_deps"], kind)
            asserts.equals(env, binary, calls[-1]["binary_target_deps"], kind)
            asserts.equals(env, "swiftpkg_foo", calls[-1]["name"])
    asserts.equals(env, 12, len(calls))
    return unittest.end(env)

inference_repository_routing_test = unittest.make(_inference_repository_routing_test)

def _header_symlinks_routing_test(ctx):
    env = unittest.begin(ctx)
    calls = []

    def _capture(**kwargs):
        calls.append(kwargs)

    from_package = struct(
        env = {},
        env_inherit = [],
        registries = {},
        resolved = None,
        make_files_read_only = False,
        netrc = None,
    )
    for kind in ["git", "local", "registry"]:
        for mode in [None, "warn", "ignore", "replace"]:
            config_pkg = None
            if mode != None:
                config_pkg = struct(
                    build_file = None,
                    init_submodules = False,
                    recursive_init_submodules = True,
                    patch_args = ["-p0"],
                    patch_cmds = [],
                    patch_cmds_win = [],
                    patch_tool = "",
                    patches = [],
                    publicly_expose_all_targets = False,
                    header_symlinks = mode,
                )
            dep = struct(
                name = "foo",
                identity = "foo",
                source_control = struct(pin = struct(
                    state = struct(revision = "abc", version = "1.0.0"),
                    location = "https://example.com/foo.git",
                )) if kind == "git" else None,
                file_system = struct(path = "/workspace/foo") if kind == "local" else None,
                registry = struct(pin = struct(identity = "example.foo", state = struct(version = "1.0.0"))) if kind == "registry" else None,
            )
            swift_deps_test_utils.declare_pkg_from_dependency(
                dep,
                config_pkg,
                from_package,
                None,
                None,
                {},
                {},
                "",
                "/workspace",
                "",
                None,
                {},
                package_rules = struct(git = _capture, local = _capture, registry = _capture),
            )
            msg = "{} mode={}".format(kind, mode)

            # Every kind receives the mode; `local_swift_package` treats
            # "replace" as "warn".
            asserts.equals(env, mode or "warn", calls[-1]["header_symlinks"], msg)
    asserts.equals(env, 12, len(calls))
    return unittest.end(env)

header_symlinks_routing_test = unittest.make(_header_symlinks_routing_test)

def _configure_package_patches_test(ctx):
    env = unittest.begin(ctx)
    calls = []

    def _capture(**kwargs):
        calls.append(kwargs)

    from_package = struct(
        env = {},
        env_inherit = [],
        registries = {},
        resolved = None,
        make_files_read_only = False,
        netrc = None,
    )
    config_pkg = struct(
        build_file = None,
        init_submodules = False,
        recursive_init_submodules = True,
        patch_args = ["-p1"],
        patch_cmds = ["echo patched"],
        patch_cmds_win = ["Write-Output patched"],
        patch_tool = "patch",
        patches = ["//patches:foo.patch"],
        publicly_expose_all_targets = False,
        header_symlinks = "warn",
    )
    for kind in ["git", "registry"]:
        dep = struct(
            name = "foo",
            identity = "foo",
            source_control = struct(pin = struct(
                state = struct(revision = "abc", version = "1.0.0"),
                location = "https://example.com/foo.git",
            )) if kind == "git" else None,
            file_system = None,
            registry = struct(pin = struct(identity = "example.foo", state = struct(version = "1.0.0"))) if kind == "registry" else None,
        )
        swift_deps_test_utils.declare_pkg_from_dependency(
            dep,
            config_pkg,
            from_package,
            None,
            None,
            {},
            {},
            "",
            "/workspace",
            "",
            None,
            {"binary_target_deps": False, "system_sdk_deps": False},
            package_rules = struct(git = _capture, local = _capture, registry = _capture),
        )
        asserts.equals(env, ["//patches:foo.patch"], calls[-1].get("patches"), kind)
        asserts.equals(env, ["-p1"], calls[-1].get("patch_args"), kind)
        asserts.equals(env, ["echo patched"], calls[-1].get("patch_cmds"), kind)
        asserts.equals(env, ["Write-Output patched"], calls[-1].get("patch_cmds_win"), kind)
        asserts.equals(env, "patch", calls[-1].get("patch_tool"), kind)
    return unittest.end(env)

configure_package_patches_test = unittest.make(_configure_package_patches_test)

_EXTENSION_METADATA_SENTINEL = struct(sentinel = "extension_metadata")

def _new_fake_module_ctx(modules, metadata):
    """Create a fake `module_ctx`.

    Args:
        modules: The fake modules for `module_ctx.modules`.
        metadata: A `dict` that receives the kwargs passed to
            `module_ctx.extension_metadata`.

    Returns:
        A `struct` that mimics a `module_ctx`. Its `extension_metadata`
        returns `_EXTENSION_METADATA_SENTINEL`, and its `is_dev_dependency`
        reads the fake tag's `is_dev` field.
    """

    def _extension_metadata(**kwargs):
        metadata.update(kwargs)
        return _EXTENSION_METADATA_SENTINEL

    return struct(
        modules = modules,
        extension_metadata = _extension_metadata,
        is_dev_dependency = lambda tag: tag.is_dev,
    )

def _extension_metadata_test(ctx):
    env = unittest.begin(ctx)

    # A repo that is both a dev and a non-dev dep is only a non-dev dep, and
    # duplicates are dropped.
    metadata = {}
    actual = swift_deps_test_utils.extension_metadata(
        _new_fake_module_ctx([], metadata),
        ["swiftpkg_foo", "swiftpkg_shared", "swiftpkg_foo"],
        ["swiftpkg_bar", "swiftpkg_shared", "swiftpkg_bar"],
    )
    asserts.equals(env, _EXTENSION_METADATA_SENTINEL, actual)
    asserts.equals(
        env,
        ["swiftpkg_foo", "swiftpkg_shared"],
        metadata["root_module_direct_deps"],
    )
    asserts.equals(
        env,
        ["swiftpkg_bar"],
        metadata["root_module_direct_dev_deps"],
    )

    return unittest.end(env)

extension_metadata_test = unittest.make(_extension_metadata_test)

def _new_ext_module(
        name,
        is_root,
        from_package_repo_names,
        dev_from_package_repo_names = None):
    """Create a fake Bazel module with `from_package` tags.

    Args:
        name: The module name.
        is_root: Whether the module is the root module.
        from_package_repo_names: The repository names that the fake non-dev
            `from_package` tag declares.
        dev_from_package_repo_names: Optional. The repository names that a
            second, dev `from_package` tag declares.

    Returns:
        A `struct` that mimics an entry in `module_ctx.modules`.
    """
    tags = {
        tag_class: []
        for tag_class in swift_deps_test_utils.bazel_target_mod_tag_classes
    }
    tags["configure_explicit_modules"] = []
    tags["configure_package"] = []
    tags["configure_swift_package"] = []
    from_package_tags = [
        struct(is_dev = False, repo_names = from_package_repo_names),
    ]
    if dev_from_package_repo_names != None:
        from_package_tags.append(
            struct(is_dev = True, repo_names = dev_from_package_repo_names),
        )
    tags["from_package"] = from_package_tags
    return struct(is_root = is_root, name = name, tags = struct(**tags))

def _run_swift_deps_impl(modules):
    """Run the `swift_deps` implementation with fake package declaration.

    Args:
        modules: The fake modules for `module_ctx.modules`.

    Returns:
        A `struct` with `declared` (the repository names declared for every
        `from_package` tag, in order), `metadata` (the kwargs passed to
        `module_ctx.extension_metadata`), and `result` (the value that the
        implementation returned).
    """
    declared = []
    metadata = {}

    def _declare_pkgs_from_package(_module_ctx, from_package, *_args):
        declared.extend(from_package.repo_names)
        return from_package.repo_names

    result = swift_deps_test_utils.swift_deps_impl(
        _new_fake_module_ctx(modules, metadata),
        declare_pkgs_from_package = _declare_pkgs_from_package,
    )
    return struct(declared = declared, metadata = metadata, result = result)

def _root_module_direct_deps_test(ctx):
    env = unittest.begin(ctx)

    # The root and a non-root module resolve different packages. Both are
    # declared, but only the root's are its direct deps.
    actual = _run_swift_deps_impl([
        _new_ext_module("my_app", True, ["swiftpkg_foo", "swiftpkg_bar"]),
        _new_ext_module("some_dep", False, ["swiftpkg_baz"]),
    ])
    asserts.equals(
        env,
        ["swiftpkg_foo", "swiftpkg_bar", "swiftpkg_baz"],
        actual.declared,
    )
    asserts.equals(
        env,
        ["swiftpkg_foo", "swiftpkg_bar"],
        actual.metadata["root_module_direct_deps"],
    )
    asserts.false(
        env,
        "swiftpkg_baz" in actual.metadata["root_module_direct_deps"],
    )
    asserts.equals(env, [], actual.metadata["root_module_direct_dev_deps"])
    asserts.equals(env, _EXTENSION_METADATA_SENTINEL, actual.result)

    # A repo that only a non-root module declares exists, but it is not
    # reported as a direct dep of the root, regardless of module order.
    actual = _run_swift_deps_impl([
        _new_ext_module("some_dep", False, ["swiftpkg_only_dep"]),
        _new_ext_module("my_app", True, []),
    ])
    asserts.equals(env, ["swiftpkg_only_dep"], actual.declared)
    asserts.equals(env, [], actual.metadata["root_module_direct_deps"])

    return unittest.end(env)

root_module_direct_deps_test = unittest.make(_root_module_direct_deps_test)

def _root_module_direct_dev_deps_test(ctx):
    env = unittest.begin(ctx)

    # Only a dev tag declares packages, so they are all direct dev deps.
    actual = _run_swift_deps_impl([
        _new_ext_module("my_app", True, [], ["swiftpkg_foo"]),
    ])
    asserts.equals(env, _EXTENSION_METADATA_SENTINEL, actual.result)
    asserts.equals(env, [], actual.metadata["root_module_direct_deps"])
    asserts.equals(
        env,
        ["swiftpkg_foo"],
        actual.metadata["root_module_direct_dev_deps"],
    )

    # A dev and a non-dev tag split the packages. A package in both is a
    # non-dev dep. A non-root module's dev tag is not reported.
    actual = _run_swift_deps_impl([
        _new_ext_module(
            "my_app",
            True,
            ["swiftpkg_foo", "swiftpkg_shared"],
            ["swiftpkg_bar", "swiftpkg_shared"],
        ),
        _new_ext_module("some_dep", False, [], ["swiftpkg_baz"]),
    ])
    asserts.equals(env, _EXTENSION_METADATA_SENTINEL, actual.result)
    asserts.equals(
        env,
        ["swiftpkg_foo", "swiftpkg_shared"],
        actual.metadata["root_module_direct_deps"],
    )
    asserts.equals(
        env,
        ["swiftpkg_bar"],
        actual.metadata["root_module_direct_dev_deps"],
    )

    return unittest.end(env)

root_module_direct_dev_deps_test = unittest.make(
    _root_module_direct_dev_deps_test,
)

def swift_deps_test_suite():
    return unittest.suite(
        "swift_deps_tests",
        inference_configuration_test,
        duplicate_package_configuration_test,
        unknown_inference_packages_test,
        inference_validation_test,
        inference_repository_routing_test,
        header_symlinks_routing_test,
        configure_package_patches_test,
        bazel_target_mods_by_repo_test,
        branch_values_test,
        build_file_conflict_error_test,
        non_root_target_mods_error_test,
        extension_metadata_test,
        root_module_direct_deps_test,
        root_module_direct_dev_deps_test,
    )
