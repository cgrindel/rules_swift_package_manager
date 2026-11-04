"""SDK inventory and generated dependency regression tests."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:bazel_target_mods.bzl", "bazel_target_mods")
load("//swiftpkg/internal:pkg_ctxs.bzl", "pkg_ctxs")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:starlark_codegen.bzl", scg = "starlark_codegen")
load("//swiftpkg/internal:swiftpkg_build_files.bzl", "swiftpkg_build_files")
load("//swiftpkg/internal:system_sdk_deps.bzl", "system_sdk_deps")
load("//swiftpkg/internal:system_sdk_modules.bzl", "system_sdk_modules")
load(":testutils.bzl", "testutils")

def _alias(name, branches):
    return "alias(\n    name = " + json.encode(name) + ",\n    actual = select({\n" + "\n".join([
        "        " + json.encode(k) + ": " + json.encode(v) + ","
        for k, v in branches.items()
    ]) + "\n    }),\n)\n"

def _sdk_alias(name, sdks):
    return _alias(name, {":" + sdk + "_sdk": ":" + sdk + "_" + name for sdk in sdks})

def _inventory_test(ctx):
    env = unittest.begin(ctx)
    names = ["Foundation", "UIKit", "Darwin", "Dispatch", "NewModule", "ExcludedModule", "DeviceOnly"]
    hub_text = "".join([
        _alias(name, {":xcode_1": "@system_sdk_xcode_1//:" + name, ":xcode_2": "@system_sdk_xcode_2//:" + name})
        for name in names
    ])
    all_sdks = ["MacOSX", "iPhoneOS", "iPhoneSimulator"]
    first = "".join([_sdk_alias(n, all_sdks) for n in names])
    second = "".join([_sdk_alias(n, all_sdks) for n in ["Foundation", "Darwin", "Dispatch"]])
    second += _sdk_alias("UIKit", ["iPhoneOS", "iPhoneSimulator"])
    second += _sdk_alias("ExcludedModule", ["MacOSX"])
    second += _sdk_alias("DeviceOnly", ["iPhoneOS"])
    result = system_sdk_modules.inventory(
        system_sdk_modules.aliases(hub_text),
        {
            "@system_sdk_xcode_1": system_sdk_modules.aliases(first),
            "@system_sdk_xcode_2": system_sdk_modules.aliases(second),
        },
    )
    asserts.equals(env, {
        "Darwin": ["ios", "macos"],
        "Dispatch": ["ios", "macos"],
        "ExcludedModule": ["macos"],
        "Foundation": ["ios", "macos"],
        "UIKit": ["ios"],
    }, result)
    asserts.equals(env, {}, system_sdk_modules.aliases('system_module_group(name = "all_modules")'))
    return unittest.end(env)

inventory_test = unittest.make(_inventory_test)

def _fixture(clang = False, resources = []):
    return pkginfos.new_target(
        name = "Example",
        type = "regular",
        c99name = "Example",
        module_type = "ClangTarget" if clang else "SwiftTarget",
        path = "Sources/Example",
        sources = ["example.m" if clang else "example.swift"],
        dependencies = [],
        repo_name = "swiftpkg_example",
        swift_src_info = None if clang else pkginfos.new_swift_src_info(),
        clang_src_info = pkginfos.new_clang_src_info(
            srcs = ["Sources/Example/example.m"],
            explicit_srcs = ["Sources/Example/example.m"],
            hdrs = ["Sources/Example/example.h"],
        ) if clang else None,
        objc_src_info = pkginfos.new_objc_src_info() if clang else None,
        linker_settings = pkginfos.new_linker_settings([
            pkginfos.new_build_setting(
                kind = "linkedFramework",
                values = ["Security", "UnknownFramework"],
                condition = pkginfos.new_build_setting_condition(platforms = ["macos"], configuration = "debug"),
            ),
        ]),
        resources = resources,
    )

def _context(target, enabled = True, manual = {}):
    return pkg_ctxs.new(
        pkg_info = pkginfos.new(name = "Example", path = ".", targets = [target]),
        repo_name = "swiftpkg_example",
        system_sdk_deps = enabled,
        target_deps = manual,
        sdk_modules = {
            "Darwin": ["ios", "macos"],
            "Dispatch": ["ios", "macos"],
            "Foundation": ["ios", "macos"],
            "Security": ["ios", "macos"],
            "UIKit": ["ios"],
        },
    )

def _generated_deps_test(ctx):
    env = unittest.begin(ctx)
    repository_ctx = testutils.new_stub_repository_ctx(
        repo_name = "swiftpkg_example",
        file_contents = {
            "Sources/Example/example.h": "#include <Darwin/stdio.h>\n/* #import <UIKit/UIKit.h> */",
            "Sources/Example/example.m": "#import <Foundation/Foundation.h>\n@import Dispatch;\n// @import UIKit;",
            "Sources/Example/example.swift": "import Foundation\nimport Darwin\nimport Dispatch\n#if canImport(UIKit)\nimport UIKit\n#endif\nimport UnknownModule",
        },
    )
    for clang in [False, True]:
        target = _fixture(clang)
        pkg_ctx = _context(target)
        build = swiftpkg_build_files.new_for_target(repository_ctx, pkg_ctx, target)
        name = "Example.rspm_objc" if clang else "Example.rspm.__impl"
        decl = [d for d in build.decls if d.name == name][0]
        deps = scg.to_starlark(decl.attrs["deps"])
        for module in ["Foundation", "Darwin", "Dispatch", "Security"]:
            asserts.true(env, "@system_sdk//:" + module in deps, deps)
        asserts.equals(env, not clang, "@system_sdk//:UIKit" in deps)
        asserts.true(env, "/platform:ios" in deps)
        asserts.true(env, "/platform:macos" in deps)
        asserts.true(env, "/platform_configuration:macos_debug" in deps)
        asserts.false(env, "/platform_configuration:ios_debug" in deps)
        asserts.false(env, "Unknown" in deps)
        asserts.false(env, "linux" in deps)
        asserts.equals(env, [], system_sdk_deps.for_target(repository_ctx, _context(target, enabled = False), target))

    target = _fixture()
    pkg_ctx = _context(target, manual = {"Example": ["@system_sdk//:Foundation"]})
    build = swiftpkg_build_files.new_for_target(repository_ctx, pkg_ctx, target)
    decl = [d for d in build.decls if d.name == "Example.rspm.__impl"][0]
    deps = scg.to_starlark(decl.attrs["deps"])
    asserts.equals(env, 1, deps.count("@system_sdk//:Foundation"))

    # Existing target modifications replace the completed dependency attribute.
    modified = bazel_target_mods.apply(build.decls, [bazel_target_mods.new(
        "set",
        "Example.rspm.__impl",
        "deps",
        value = ["//:replacement"],
    )])
    modified_decl = [d for d in modified if d.name == decl.name][0]
    asserts.equals(env, ["//:replacement"], modified_decl.attrs["deps"])
    return unittest.end(env)

generated_deps_test = unittest.make(_generated_deps_test)

def system_sdk_test_suite():
    return unittest.suite("system_sdk_tests", inventory_test, generated_deps_test)
