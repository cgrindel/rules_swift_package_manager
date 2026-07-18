"""Tests for `pkg_ctxs`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:pkg_ctxs.bzl", "pkg_ctxs")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")

_swift_log = pkginfos.new_dependency(identity = "swift-log", name = "swift-log")
_swift_game = pkginfos.new_dependency(identity = "swift-game", name = "swift-game")

def _module_alias_flags_test(ctx):
    env = unittest.begin(ctx)

    tests = [
        struct(
            msg = "no aliases",
            deps = [],
            module_aliases = {},
            dep_module_aliases = "",
            exp_module_aliases = {},
            exp_flags = {},
        ),
        struct(
            msg = "own aliases only, no dependencies",
            deps = [],
            module_aliases = {"Utils": "GameUtils"},
            dep_module_aliases = "",
            exp_module_aliases = {"Utils": "GameUtils"},
            exp_flags = {"Utils": "GameUtils"},
        ),
        struct(
            msg = "a dependency's alias propagates to a direct dependent",
            deps = [_swift_log],
            module_aliases = {},
            dep_module_aliases = json.encode(
                {"swift-log": {"Logging": "SwiftLog"}},
            ),
            exp_module_aliases = {},
            exp_flags = {"Logging": "SwiftLog"},
        ),
        struct(
            msg = "an alias for a non-dependency identity is ignored",
            deps = [_swift_game],
            module_aliases = {},
            dep_module_aliases = json.encode(
                {"swift-log": {"Logging": "SwiftLog"}},
            ),
            exp_module_aliases = {},
            exp_flags = {},
        ),
        struct(
            msg = "own and propagated aliases are merged",
            deps = [_swift_log],
            module_aliases = {"Utils": "GameUtils"},
            dep_module_aliases = json.encode({
                "swift-game": {"Utils": "GameUtils"},
                "swift-log": {"Logging": "SwiftLog"},
            }),
            exp_module_aliases = {"Utils": "GameUtils"},
            exp_flags = {"Logging": "SwiftLog", "Utils": "GameUtils"},
        ),
    ]

    for t in tests:
        pkg_ctx = pkg_ctxs.new(
            pkg_info = struct(dependencies = t.deps),
            repo_name = "@swiftpkg_swift_game",
            module_aliases = t.module_aliases,
            dep_module_aliases = t.dep_module_aliases,
        )
        asserts.equals(
            env,
            t.exp_module_aliases,
            pkg_ctx.module_aliases,
            "{}: module_aliases".format(t.msg),
        )
        asserts.equals(
            env,
            t.exp_flags,
            pkg_ctx.module_alias_flags,
            "{}: module_alias_flags".format(t.msg),
        )

    return unittest.end(env)

module_alias_flags_test = unittest.make(_module_alias_flags_test)

def pkg_ctxs_test_suite():
    return unittest.suite(
        "pkg_ctxs_tests",
        module_alias_flags_test,
    )
