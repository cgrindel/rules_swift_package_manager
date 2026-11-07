"""SDK inventory and generated dependency regression tests."""

load("@bazel_skylib//lib:structs.bzl", "structs")
load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//swiftpkg/internal:bazel_target_mods.bzl", "bazel_target_mods")
load("//swiftpkg/internal:clang_files.bzl", "clang_files")
load("//swiftpkg/internal:dependency_modules.bzl", "dependency_modules")
load("//swiftpkg/internal:pkg_ctxs.bzl", "pkg_ctxs")
load("//swiftpkg/internal:pkginfos.bzl", "pkginfos")
load("//swiftpkg/internal:sdk_inference_context.bzl", "sdk_inference_context")
load("//swiftpkg/internal:starlark_codegen.bzl", scg = "starlark_codegen")
load("//swiftpkg/internal:swiftpkg_build_files.bzl", "swiftpkg_build_files")
load("//swiftpkg/internal:system_sdk_deps.bzl", "system_sdk_deps")
load("//swiftpkg/internal:system_sdk_labels.bzl", "system_sdk_labels")
load(":testutils.bzl", "testutils")

def _inventory(modules):
    conditions = {}
    references = {}
    for module, entries in modules.items():
        references[module] = []
        for original in entries:
            entry = dict(original)
            key = entry.get("sdk", entry["condition"])
            entry["sdk"] = key
            entry.setdefault("configurations", {c: entry["condition"] + "_" + c for c in ["debug", "release", "fastbuild"]})
            conditions[key] = entry
            references[module].append(key)
    return struct(conditions = conditions, diagnostic = "", modules = references)

def _fixture(clang = False, resources = [], linker_settings = None, dependencies = []):
    return pkginfos.new_target(
        name = "Example",
        type = "regular",
        c99name = "Example",
        module_type = "ClangTarget" if clang else "SwiftTarget",
        path = "Sources/Example",
        sources = ["example.m" if clang else "example.swift"],
        dependencies = dependencies,
        repo_name = "swiftpkg_example",
        swift_src_info = None if clang else pkginfos.new_swift_src_info(),
        clang_src_info = pkginfos.new_clang_src_info(
            srcs = ["Sources/Example/example.m"],
            explicit_srcs = ["Sources/Example/example.m"],
            hdrs = ["Sources/Example/example.h"],
        ) if clang else None,
        objc_src_info = pkginfos.new_objc_src_info() if clang else None,
        linker_settings = linker_settings or pkginfos.new_linker_settings([
            pkginfos.new_build_setting(
                kind = "linkedFramework",
                values = ["Security", "UnknownFramework"],
                condition = pkginfos.new_build_setting_condition(platforms = ["macos"], configuration = "debug"),
            ),
        ]),
        resources = resources,
    )

def _entries(platforms):
    return [
        {
            "condition": "@inventory//:xcode1_" + platform,
            "configurations": {c: "@inventory//:xcode1_" + platform + "_" + c for c in ["debug", "release"]},
            "platform": platform,
        }
        for platform in platforms
    ]

def _with_inventory(pkg_ctx, inventory, dependency_modules = {}, source_modules = ["Foundation", "Darwin", "Dispatch", "UIKit", "AppKit", "XCTest"]):
    fields = structs.to_dict(pkg_ctx)
    fields.update(sdk_modules = inventory, dependency_modules = dependency_modules)
    fields["source_scans"] = {target.name: [
        {"condition": label, "configuration": config, "imports": source_modules, "sdk": entry["sdk"]}
        for entry in inventory.conditions.values()
        for config, label in entry["configurations"].items()
    ] for target in pkg_ctx.pkg_info.targets if target.swift_src_info}
    return struct(**fields)

def _context(target, enabled = True, manual = {}, dependency_modules = {}):
    return _with_inventory(
        pkg_ctxs.new(
            pkg_info = pkginfos.new(name = "Example", path = ".", targets = [target]),
            repo_name = "swiftpkg_example",
            system_sdk_deps = enabled,
            target_deps = manual,
        ),
        _inventory({
            "Darwin": _entries(["ios", "macos"]),
            "Dispatch": _entries(["ios", "macos"]),
            "Foundation": _entries(["ios", "macos"]),
            "Security": _entries(["ios", "macos"]),
            "UIKit": _entries(["ios"]),
        }),
        dependency_modules = dependency_modules,
    )

def _disabled_test(ctx):
    env = unittest.begin(ctx)
    target = _fixture()
    pkg_ctx = pkg_ctxs.new(
        pkg_info = pkginfos.new(name = "Example", path = ".", targets = [target]),
        repo_name = "swiftpkg_example",
        system_sdk_deps = False,
    )

    # Disabled inference must not inspect the provider or read package files.
    repository_ctx = struct(read = lambda path: fail("Unexpected inference read: " + str(path)))
    for context in [pkg_ctx, _with_inventory(pkg_ctx, _inventory({}))]:
        asserts.equals(env, context, sdk_inference_context.prepare(repository_ctx, context))
        asserts.equals(env, [], system_sdk_deps.for_target(repository_ctx, context, target))
    return unittest.end(env)

disabled_test = unittest.make(_disabled_test)

def _generated_deps_test(ctx):
    env = unittest.begin(ctx)
    repository_ctx = testutils.new_stub_repository_ctx(
        repo_name = "swiftpkg_example",
        file_contents = {
            "Sources/Example/example.h": "#include <stdio.h>\n/* #import <UIKit/UIKit.h> */",
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
        asserts.true(env, '"@inventory//:xcode1_ios"' in deps)
        asserts.true(env, '"@inventory//:xcode1_macos"' in deps)
        asserts.true(env, "xcode1_macos_debug" in deps)
        asserts.false(env, "xcode1_ios_debug" in deps)
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

def _regressions_test(ctx):
    env = unittest.begin(ctx)
    repository_ctx = testutils.new_stub_repository_ctx(repo_name = "swiftpkg_example")
    configured = pkginfos.new_build_setting("linkedFramework", ["Security"], pkginfos.new_build_setting_condition(configuration = "debug"))
    unconditional = pkginfos.new_build_setting("linkedFramework", ["Security"])
    for settings in [[configured, unconditional], [unconditional, configured]]:
        target = _fixture(linker_settings = pkginfos.new_linker_settings(settings))
        deps = system_sdk_deps.for_target(repository_ctx, _context(target), target)
        asserts.equals(env, 2, len([d for d in deps if d.value == "@system_sdk//:Security"]))
        asserts.false(env, any([d.condition.endswith("_debug") for d in deps]))

    for header, module in [
        ("dispatch/dispatch.h", "Dispatch"),
        ("objc/runtime.h", "ObjectiveC"),
        ("sqlite3.h", "SQLite3"),
        ("stdio.h", "Darwin"),
        ("sys/types.h", "Darwin"),
        ("TargetConditionals.h", "TargetConditionals"),
    ]:
        asserts.equals(env, {module: True}, clang_files.imports("#include <" + header + ">\n"))
    asserts.equals(env, '#import "local.h"\n', clang_files.scan_prefix('#import "local.h"\nint body = 0;\n'))

    contents = """const char *s = "/*";
#import <Foundation/Foundation.h>
const char *raw = R"tag(
#import <UIKit/UIKit.h>
)tag";
@import Dispatch;
char slash = '/';
"""
    asserts.equals(env, {"Dispatch": True, "Foundation": True}, clang_files.imports(contents))
    asserts.equals(env, {"Foundation": True}, clang_files.imports("#error can't compile\n#import <Foundation/Foundation.h>\n"))
    asserts.equals(env, {"Foundation": True}, clang_files.imports("int n = 0x1'FF;\n#import <Foundation/Foundation.h>\n"))
    asserts.equals(env, "#import <Foundation/Foundation.h>\n", clang_files.scan_prefix("#import <Foundation/Foundation.h>\nint longBody = 1;\n"))

    target = _fixture()
    repository_ctx = testutils.new_stub_repository_ctx(repo_name = "swiftpkg_example", file_contents = {
        "Sources/Example/example.swift": "import Dispatch\n#if canImport(Foundation)\nimport Foundation\n#endif",
    })
    deps = system_sdk_deps.for_target(repository_ctx, _context(target, dependency_modules = {"Example": {"ios": ["Dispatch"], "macos": ["Dispatch"]}}), target)
    asserts.false(env, any([d.value == "@system_sdk//:Dispatch" for d in deps]))
    asserts.true(env, any([d.value == "@system_sdk//:Foundation" for d in deps]))

    info = pkginfos.new(name = "Consumer", path = ".", targets = [_fixture(dependencies = [
        pkginfos.new_target_dependency(product = pkginfos.new_product_reference("TestSupportProduct", "test-support")),
    ])], dependencies = [pkginfos.new_dependency(identity = "test-support", name = "test-support")])
    modules = dependency_modules.for_package(info, {"test-support": {
        "products": [{"name": "TestSupportProduct", "targets": ["Facade"]}],
        "targets": [
            {"c99name": "Facade", "dependencies": [{"target": {"target_name": "ActualTests"}}], "name": "Facade"},
            {"c99name": "Testing", "dependencies": [], "name": "ActualTests"},
        ],
    }}, ["ios"])
    asserts.equals(env, {"Example": {"ios": ["Example", "Facade", "Testing"]}}, modules)

    return unittest.end(env)

regressions_test = unittest.make(_regressions_test)

def _sdk_identity_test(ctx):
    env = unittest.begin(ctx)
    apparent = "@system_sdk//:Foundation"
    canonical = system_sdk_labels.key(apparent)
    target = _fixture()
    repo = testutils.new_stub_repository_ctx(repo_name = "swiftpkg_example", file_contents = {"Sources/Example/example.swift": "import Foundation"})
    build = swiftpkg_build_files.new_for_target(repo, _context(target, manual = {"Example": [canonical]}), target)
    decl = [d for d in build.decls if d.name == "Example.rspm.__impl"][0]
    rendered = scg.to_starlark(decl.attrs["deps"])
    asserts.equals(env, 1, rendered.count(canonical))
    asserts.false(env, apparent in rendered)

    return unittest.end(env)

sdk_identity_test = unittest.make(_sdk_identity_test)

def _platform_exclusions_test(ctx):
    env = unittest.begin(ctx)
    target = _fixture()
    repo = testutils.new_stub_repository_ctx(repo_name = "swiftpkg_example", file_contents = {"Sources/Example/example.swift": "import Dispatch"})
    pkg_ctx = _context(target, dependency_modules = {"Example": {"ios": ["Dispatch"], "macos": []}})
    deps = system_sdk_deps.for_target(repo, pkg_ctx, target)
    asserts.equals(env, ["@inventory//:xcode1_macos"], [d.condition for d in deps if d.value == "@system_sdk//:Dispatch"])
    return unittest.end(env)

platform_exclusions_test = unittest.make(_platform_exclusions_test)

def _compiler_results_test(ctx):
    env = unittest.begin(ctx)
    target = _fixture()
    repository_ctx = testutils.new_stub_repository_ctx(repo_name = "swiftpkg_example")
    pkg_ctx = _with_inventory(
        pkg_ctxs.new(
            pkg_info = pkginfos.new(name = "Example", path = ".", targets = [target]),
            repo_name = "swiftpkg_example",
            system_sdk_deps = True,
        ),
        _inventory({
            "AppKit": [{"condition": "//:macos", "environment": "device", "platform": "macos"}],
            "Darwin": [{"condition": "//:ios", "environment": "device", "platform": "ios"}],
            "Dispatch": [
                {"condition": "//:ios_device", "environment": "device", "platform": "ios"},
                {"condition": "//:ios_sim", "environment": "simulator", "platform": "ios"},
            ],
            "Foundation": [{"condition": "//:macos", "environment": "device", "platform": "macos"}],
            "UIKit": [{"condition": "//:ios", "environment": "device", "platform": "ios"}],
            "XCTest": [{"condition": "//:ios", "environment": "device", "platform": "ios"}],
        }),
    )
    deps = system_sdk_deps.for_target(repository_ctx, pkg_ctx, target)
    labels = {(d.value, d.condition): True for d in deps}
    for pair in [("@system_sdk//:UIKit", "//:ios"), ("@system_sdk//:AppKit", "//:macos"), ("@system_sdk//:Dispatch", "//:ios_sim"), ("@system_sdk//:Foundation", "//:macos"), ("@system_sdk//:XCTest", "//:ios"), ("@system_sdk//:Darwin", "//:ios"), ("@system_sdk//:Dispatch", "//:ios_device")]:
        asserts.true(env, pair in labels, labels)
    return unittest.end(env)

compiler_results_test = unittest.make(_compiler_results_test)

def system_sdk_test_suite(name = "system_sdk_tests"):
    unittest.suite("system_sdk_unit_tests", disabled_test, generated_deps_test, regressions_test, sdk_identity_test, platform_exclusions_test, compiler_results_test)
    native.test_suite(name = name, tests = [":system_sdk_unit_tests"])
