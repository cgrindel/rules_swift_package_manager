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
            pkg_info = struct(
                name = "swift-game",
                dependencies = t.deps,
                platforms = [],
                products = [],
                targets = [],
            ),
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

def _minimum_os_versions_test(ctx):
    env = unittest.begin(ctx)

    pkg_info = struct(
        name = "swift-game",
        dependencies = [_swift_log],
        platforms = [pkginfos.new_platform("ios", "13.0")],
        products = [struct(name = "Game", targets = ["Game"])],
        targets = [
            struct(
                name = "Game",
                type = "regular",
                dependencies = [
                    pkginfos.new_target_dependency(
                        product = pkginfos.new_product_reference("Logging", "swift-log"),
                    ),
                ],
            ),
            struct(name = "GameUtils", type = "regular", dependencies = []),
        ],
    )

    declared_only = pkg_ctxs.new(pkg_info = pkg_info, repo_name = "@swiftpkg_swift_game")
    asserts.equals(env, "13.0", declared_only.minimum_os_versions.targets["Game"]["ios"])
    asserts.equals(env, "10.13", declared_only.minimum_os_versions.package["macos"])

    raised = pkg_ctxs.new(
        pkg_info = pkg_info,
        repo_name = "@swiftpkg_swift_game",
        dep_minimum_os_versions = {
            "swift-log": {
                "package": {"ios": "15.0", "macos": "12.0"},
                "products": {"Logging": {"ios": "15.0", "macos": "12.0"}},
            },
        },
    )
    asserts.equals(env, {
        "ios": "15.0",
        "macos": "12.0",
        "tvos": "12.0",
        "visionos": "1.0",
        "watchos": "4.0",
    }, raised.minimum_os_versions.targets["Game"])
    asserts.equals(env, "13.0", raised.minimum_os_versions.targets["GameUtils"]["ios"])
    asserts.equals(env, "15.0", raised.minimum_os_versions.products["Game"]["ios"])
    asserts.equals(env, "15.0", raised.minimum_os_versions.package["ios"])

    return unittest.end(env)

minimum_os_versions_test = unittest.make(_minimum_os_versions_test)

def _referenced_dependency_identities_test(ctx):
    env = unittest.begin(ctx)

    pkg_info = struct(
        name = "swift-game",
        dependencies = [
            _swift_log,
            pkginfos.new_dependency(identity = "swift-parsing", name = "swift-parsing"),
            pkginfos.new_dependency(identity = "swift-testing-only", name = "swift-testing-only"),
            pkginfos.new_dependency(identity = "swift-unused", name = "swift-unused"),
        ],
        products = [struct(name = "GameProduct")],
        targets = [
            struct(
                name = "Game",
                type = "regular",
                dependencies = [
                    pkginfos.new_target_dependency(
                        product = pkginfos.new_product_reference("Logging", "swift-log"),
                    ),
                    pkginfos.new_target_dependency(
                        by_name = pkginfos.new_by_name_reference("swift-parsing"),
                    ),
                    pkginfos.new_target_dependency(
                        by_name = pkginfos.new_by_name_reference("GameUtils"),
                    ),
                    pkginfos.new_target_dependency(
                        by_name = pkginfos.new_by_name_reference("GameProduct"),
                    ),
                    pkginfos.new_target_dependency(
                        product = pkginfos.new_product_reference("GameProduct", "swift-game"),
                    ),
                    pkginfos.new_target_dependency(
                        target = pkginfos.new_target_reference("GameUtils"),
                    ),
                ],
            ),
            struct(name = "GameUtils", type = "regular", dependencies = []),
            struct(
                name = "GameTests",
                type = "test",
                dependencies = [
                    pkginfos.new_target_dependency(
                        product = pkginfos.new_product_reference("Testing", "swift-testing-only"),
                    ),
                ],
            ),
        ],
    )

    asserts.equals(
        env,
        ["swift-log", "swift-parsing"],
        pkg_ctxs.referenced_dependency_identities(pkg_info),
    )

    return unittest.end(env)

referenced_dependency_identities_test = unittest.make(_referenced_dependency_identities_test)

def pkg_ctxs_test_suite():
    return unittest.suite(
        "pkg_ctxs_tests",
        module_alias_flags_test,
        minimum_os_versions_test,
        referenced_dependency_identities_test,
    )
