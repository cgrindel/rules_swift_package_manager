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

def swift_deps_test_suite():
    return unittest.suite(
        "swift_deps_tests",
        bazel_target_mods_by_repo_test,
        branch_values_test,
        build_file_conflict_error_test,
        non_root_target_mods_error_test,
    )
