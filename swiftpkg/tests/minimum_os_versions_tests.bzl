"""Tests for package minimum OS version helpers."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:minimum_os_versions.bzl", "minimum_os_versions")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")

def _pkg_info(platforms = []):
    return struct(platforms = platforms)

def _ios(version):
    return pkginfos.new_platform("iOS", version)

def _macos(version):
    return pkginfos.new_platform("macOS", version)

def _transition_attrs_uses_declared_versions_test(ctx):
    env = unittest.begin(ctx)

    attrs = minimum_os_versions.transition_attrs(
        minimum_os_versions.by_platform(_pkg_info(platforms = [
            _ios("13.0"),
            _macos("10.15"),
            pkginfos.new_platform("tvOS", "13.0"),
            pkginfos.new_platform("visionOS", "1.0"),
            pkginfos.new_platform("watchOS", "6.0"),
        ])),
    )

    asserts.equals(env, {
        "ios_minimum_os": "13.0",
        "macos_minimum_os": "10.15",
        "tvos_minimum_os": "13.0",
        "visionos_minimum_os": "1.0",
        "watchos_minimum_os": "6.0",
    }, attrs)

    return unittest.end(env)

transition_attrs_uses_declared_versions_test = unittest.make(_transition_attrs_uses_declared_versions_test)

def _transition_attrs_uses_fallbacks_for_omitted_platforms_test(ctx):
    env = unittest.begin(ctx)

    attrs = minimum_os_versions.transition_attrs(
        minimum_os_versions.by_platform(_pkg_info(platforms = [
            _ios("13.0"),
            pkginfos.new_platform("linux", "5.0"),
        ])),
    )

    asserts.equals(env, {
        "ios_minimum_os": "13.0",
        "macos_minimum_os": "10.13",
        "tvos_minimum_os": "12.0",
        "visionos_minimum_os": "1.0",
        "watchos_minimum_os": "4.0",
    }, attrs)

    return unittest.end(env)

transition_attrs_uses_fallbacks_for_omitted_platforms_test = unittest.make(_transition_attrs_uses_fallbacks_for_omitted_platforms_test)

def _fallback_accepts_package_description_spelling_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, "1.0", minimum_os_versions.fallback("visionOS"))

    return unittest.end(env)

fallback_accepts_package_description_spelling_test = unittest.make(_fallback_accepts_package_description_spelling_test)

def _by_platform_raises_to_dependency_versions_test(ctx):
    env = unittest.begin(ctx)

    # swift-parsing declares iOS 13 / macOS 10.15 and depends on
    # swift-case-paths, which declares iOS 15 / macOS 12.
    case_paths = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_ios("15.0"), _macos("12.0")]),
    )
    parsing = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_ios("13.0"), _macos("10.15")]),
        dep_versions = [case_paths],
    )

    asserts.equals(env, "15.0", parsing["ios"])
    asserts.equals(env, "12.0", parsing["macos"])
    asserts.equals(env, "12.0", parsing["tvos"])
    asserts.equals(env, "1.0", parsing["visionos"])
    asserts.equals(env, "4.0", parsing["watchos"])

    return unittest.end(env)

by_platform_raises_to_dependency_versions_test = unittest.make(_by_platform_raises_to_dependency_versions_test)

def _by_platform_never_lowers_declared_versions_test(ctx):
    env = unittest.begin(ctx)

    dep = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_ios("12.0"), _macos("10.13")]),
    )
    actual = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_ios("16.0"), _macos("13.0")]),
        dep_versions = [dep],
    )

    asserts.equals(env, "16.0", actual["ios"])
    asserts.equals(env, "13.0", actual["macos"])

    return unittest.end(env)

by_platform_never_lowers_declared_versions_test = unittest.make(_by_platform_never_lowers_declared_versions_test)

def _by_platform_propagates_through_chain_test(ctx):
    env = unittest.begin(ctx)

    # leaf (iOS 17) <- middle (iOS 13) <- root (iOS 12 fallback). The root
    # does not depend on the leaf directly; it inherits the leaf's floor via
    # the middle package's effective versions.
    leaf = minimum_os_versions.by_platform(_pkg_info(platforms = [_ios("17.0")]))
    middle = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_ios("13.0")]),
        dep_versions = [leaf],
    )
    root = minimum_os_versions.by_platform(
        _pkg_info(),
        dep_versions = [middle],
    )

    asserts.equals(env, "17.0", middle["ios"])
    asserts.equals(env, "17.0", root["ios"])

    return unittest.end(env)

by_platform_propagates_through_chain_test = unittest.make(_by_platform_propagates_through_chain_test)

def _by_platform_takes_maximum_across_diamond_test(ctx):
    env = unittest.begin(ctx)

    # root -> left -> shared, root -> right -> shared. Each branch raises a
    # different platform; the root ends up with the maximum of each.
    shared = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_ios("14.0"), _macos("11.0")]),
    )
    left = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_ios("15.0")]),
        dep_versions = [shared],
    )
    right = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_macos("12.0")]),
        dep_versions = [shared],
    )
    root = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_ios("13.0"), _macos("10.15")]),
        dep_versions = [left, right],
    )

    asserts.equals(env, "15.0", root["ios"])
    asserts.equals(env, "12.0", root["macos"])

    return unittest.end(env)

by_platform_takes_maximum_across_diamond_test = unittest.make(_by_platform_takes_maximum_across_diamond_test)

def _by_platform_uses_dependency_fallback_when_platform_absent_test(ctx):
    env = unittest.begin(ctx)

    # The dependency does not declare iOS, so its effective iOS floor is the
    # SwiftPM fallback (12.0), which must not raise the importer's 13.0.
    dep = minimum_os_versions.by_platform(_pkg_info(platforms = [_macos("14.0")]))
    actual = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_ios("13.0")]),
        dep_versions = [dep],
    )

    asserts.equals(env, "12.0", dep["ios"])
    asserts.equals(env, "13.0", actual["ios"])
    asserts.equals(env, "14.0", actual["macos"])

    return unittest.end(env)

by_platform_uses_dependency_fallback_when_platform_absent_test = unittest.make(_by_platform_uses_dependency_fallback_when_platform_absent_test)

def _by_platform_adopts_platform_declared_only_by_dependency_test(ctx):
    env = unittest.begin(ctx)

    # The importer only declares iOS; its tvOS floor is the fallback (12.0)
    # and is raised to the dependency's declared tvOS 16.
    dep = minimum_os_versions.by_platform(
        _pkg_info(platforms = [pkginfos.new_platform("tvOS", "16.0")]),
    )
    actual = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_ios("13.0")]),
        dep_versions = [dep],
    )

    asserts.equals(env, "13.0", actual["ios"])
    asserts.equals(env, "16.0", actual["tvos"])

    return unittest.end(env)

by_platform_adopts_platform_declared_only_by_dependency_test = unittest.make(_by_platform_adopts_platform_declared_only_by_dependency_test)

def _by_platform_ignores_unsupported_dependency_platforms_test(ctx):
    env = unittest.begin(ctx)

    actual = minimum_os_versions.by_platform(
        _pkg_info(platforms = [_ios("13.0")]),
        dep_versions = [{"ios": "13.1", "linux": "99.0", "macos": ""}],
    )

    asserts.equals(env, {
        "ios": "13.1",
        "macos": "10.13",
        "tvos": "12.0",
        "visionos": "1.0",
        "watchos": "4.0",
    }, actual)

    return unittest.end(env)

by_platform_ignores_unsupported_dependency_platforms_test = unittest.make(_by_platform_ignores_unsupported_dependency_platforms_test)

def _is_higher_compares_numerically_test(ctx):
    env = unittest.begin(ctx)

    asserts.true(env, minimum_os_versions.is_higher("10.15", "10.13"))
    asserts.true(env, minimum_os_versions.is_higher("15.0", "9.0"))
    asserts.true(env, minimum_os_versions.is_higher("13.0.2", "13.0.1"))
    asserts.false(env, minimum_os_versions.is_higher("13.0", "13"))
    asserts.false(env, minimum_os_versions.is_higher("12.0", "13.0"))

    return unittest.end(env)

is_higher_compares_numerically_test = unittest.make(_is_higher_compares_numerically_test)

def _target(name, dependencies = [], type = "regular"):
    return struct(name = name, type = type, dependencies = dependencies)

def _product_dep(product_name, dep_name):
    return pkginfos.new_target_dependency(
        product = pkginfos.new_product_reference(product_name, dep_name),
    )

def _by_name_dep(name):
    return pkginfos.new_target_dependency(
        by_name = pkginfos.new_by_name_reference(name),
    )

def _target_dep(name):
    return pkginfos.new_target_dependency(
        target = pkginfos.new_target_reference(name),
    )

_CASE_PATHS = pkginfos.new_dependency(identity = "swift-case-paths", name = "swift-case-paths")

def _exported(ios, macos, products):
    versions = {"ios": ios, "macos": macos}
    return {
        "package": versions,
        "products": {name: versions for name in products},
    }

def _for_targets_raises_only_importing_targets_test(ctx):
    env = unittest.begin(ctx)

    # `Client` never imports the higher-floor dependency; only `Backend` and
    # the targets depending on it (via target, by-name and product references)
    # are raised. Test targets are ignored.
    pkg_info = struct(
        name = "xcmetrics",
        dependencies = [_CASE_PATHS],
        platforms = [_ios("13.0"), _macos("10.15")],
        products = [
            struct(name = "Client", targets = ["Client"]),
            struct(name = "Backend", targets = ["Backend"]),
            struct(name = "Server", targets = ["Server", "Client"]),
        ],
        targets = [
            _target("Client"),
            _target("Backend", [_product_dep("CasePaths", "swift-case-paths")]),
            _target("Server", [_target_dep("Backend")]),
            _target("Plugin", [_by_name_dep("Server")]),
            _target("App", [_product_dep("Backend", "xcmetrics")]),
            _target("BackendTests", [_by_name_dep("Backend")], type = "test"),
        ],
    )

    effective = minimum_os_versions.for_targets(
        pkg_info,
        {"swift-case-paths": _exported("15.0", "12.0", ["CasePaths"])},
    )

    asserts.equals(env, "13.0", effective.targets["Client"]["ios"])
    asserts.equals(env, "10.15", effective.targets["Client"]["macos"])
    for name in ["Backend", "Server", "Plugin", "App"]:
        asserts.equals(env, "15.0", effective.targets[name]["ios"], name)
        asserts.equals(env, "12.0", effective.targets[name]["macos"], name)
    asserts.false(env, "BackendTests" in effective.targets)

    asserts.equals(env, "13.0", effective.products["Client"]["ios"])
    asserts.equals(env, "15.0", effective.products["Backend"]["ios"])
    asserts.equals(env, "15.0", effective.products["Server"]["ios"])
    asserts.equals(env, "15.0", effective.package["ios"])
    asserts.equals(env, "12.0", effective.package["macos"])

    return unittest.end(env)

for_targets_raises_only_importing_targets_test = unittest.make(_for_targets_raises_only_importing_targets_test)

def _for_targets_uses_package_maximum_for_unknown_product_test(ctx):
    env = unittest.begin(ctx)

    pkg_info = struct(
        name = "swift-parsing",
        dependencies = [_CASE_PATHS],
        platforms = [_ios("13.0")],
        products = [],
        targets = [
            _target("Parsing", [_product_dep("Unlisted", "swift-case-paths")]),
            _target("ByName", [_by_name_dep("swift-case-paths")]),
            _target("Unknown", [_product_dep("Foo", "not-a-dependency")]),
        ],
    )

    effective = minimum_os_versions.for_targets(
        pkg_info,
        {"swift-case-paths": _exported("15.0", "12.0", ["CasePaths"])},
    )

    asserts.equals(env, "15.0", effective.targets["Parsing"]["ios"])
    asserts.equals(env, "15.0", effective.targets["ByName"]["ios"])
    asserts.equals(env, "13.0", effective.targets["Unknown"]["ios"])

    # Without exported versions for the dependency, declared floors apply.
    declared_only = minimum_os_versions.for_targets(pkg_info)
    asserts.equals(env, "13.0", declared_only.targets["Parsing"]["ios"])
    asserts.equals(env, "13.0", declared_only.package["ios"])

    return unittest.end(env)

for_targets_uses_package_maximum_for_unknown_product_test = unittest.make(_for_targets_uses_package_maximum_for_unknown_product_test)

def minimum_os_versions_test_suite():
    return unittest.suite(
        "minimum_os_versions_tests",
        transition_attrs_uses_declared_versions_test,
        transition_attrs_uses_fallbacks_for_omitted_platforms_test,
        fallback_accepts_package_description_spelling_test,
        by_platform_raises_to_dependency_versions_test,
        by_platform_never_lowers_declared_versions_test,
        by_platform_propagates_through_chain_test,
        by_platform_takes_maximum_across_diamond_test,
        by_platform_uses_dependency_fallback_when_platform_absent_test,
        by_platform_adopts_platform_declared_only_by_dependency_test,
        by_platform_ignores_unsupported_dependency_platforms_test,
        is_higher_compares_numerically_test,
        for_targets_raises_only_importing_targets_test,
        for_targets_uses_package_maximum_for_unknown_product_test,
    )
