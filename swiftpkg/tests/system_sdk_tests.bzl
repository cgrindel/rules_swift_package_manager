"""SDK inventory and generated dependency regression tests."""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")
load("//swiftpkg/internal:bazel_target_mods.bzl", "bazel_target_mods")
load("//swiftpkg/internal:dependency_normalization.bzl", "dependency_normalization")
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
    asserts.equals(env, 6, len(result["Foundation"]))
    asserts.equals(env, 5, len(result["UIKit"]))
    asserts.equals(env, 4, len(result["DeviceOnly"]))
    asserts.equals(env, 3, len(result["NewModule"]))
    asserts.equals(env, "ios", result["DeviceOnly"][-1]["platform"])
    asserts.equals(env, ":iPhoneOS_sdk", result["DeviceOnly"][-1]["sdk_condition"])
    asserts.equals(env, {}, system_sdk_modules.aliases('system_module_group(name = "all_modules")'))
    asserts.equals(env, None, system_sdk_modules.aliases('alias(name = "Foundation", actual = ":custom")'))
    asserts.equals(env, None, system_sdk_modules.aliases('alias(\nname = "X",\nactual = ":X",\n)'))
    return unittest.end(env)

inventory_test = unittest.make(_inventory_test)

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

def _context(target, enabled = True, manual = {}, dependency_modules = {}):
    return pkg_ctxs.new(
        pkg_info = pkginfos.new(name = "Example", path = ".", targets = [target]),
        repo_name = "swiftpkg_example",
        system_sdk_deps = enabled,
        target_deps = manual,
        dependency_modules = dependency_modules,
        sdk_modules = {
            "Darwin": _entries(["ios", "macos"]),
            "Dispatch": _entries(["ios", "macos"]),
            "Foundation": _entries(["ios", "macos"]),
            "Security": _entries(["ios", "macos"]),
            "UIKit": _entries(["ios"]),
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
        asserts.true(env, "xcode1_ios" in deps)
        asserts.true(env, "xcode1_macos" in deps)
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
        asserts.equals(env, 2, len(deps))
        asserts.false(env, any([d.condition.endswith("_debug") for d in deps]))

    contents = """const char *s = "/*";
#import <Foundation/Foundation.h>
const char *raw = R"tag(
#import <UIKit/UIKit.h>
)tag";
@import Dispatch;
char slash = '/';
"""
    asserts.equals(env, {"Dispatch": True, "Foundation": True}, system_sdk_deps.clang_imports(contents))
    asserts.equals(env, {"Foundation": True}, system_sdk_deps.clang_imports("#error can't compile\n#import <Foundation/Foundation.h>\n"))
    asserts.equals(env, {"Foundation": True}, system_sdk_deps.clang_imports("int n = 0x1'FF;\n#import <Foundation/Foundation.h>\n"))
    asserts.equals(env, "#import <Foundation/Foundation.h>\n", system_sdk_deps.scan_prefix("#import <Foundation/Foundation.h>\nint longBody = 1;\n"))

    target = _fixture()
    repository_ctx = testutils.new_stub_repository_ctx(repo_name = "swiftpkg_example", file_contents = {
        "Sources/Example/example.swift": "import Dispatch\n#if canImport(Foundation)\nimport Foundation\n#endif",
    })
    deps = system_sdk_deps.for_target(repository_ctx, _context(target, dependency_modules = {"Example": ["Dispatch"]}), target)
    asserts.false(env, any([d.value == "@system_sdk//:Dispatch" for d in deps]))
    asserts.true(env, any([d.value == "@system_sdk//:Foundation" for d in deps]))

    info = pkginfos.new(name = "Consumer", path = ".", targets = [_fixture(dependencies = [
        pkginfos.new_target_dependency(product = pkginfos.new_product_reference("TestSupportProduct", "test-support")),
    ])], dependencies = [pkginfos.new_dependency(identity = "test-support", name = "test-support")])
    modules = pkg_ctxs.dependency_modules(info, {"test-support": {
        "products": [{"name": "TestSupportProduct", "targets": ["Facade"]}],
        "targets": [
            {"c99name": "Facade", "dependencies": [{"target": {"target_name": "ActualTests"}}], "name": "Facade"},
            {"c99name": "Testing", "dependencies": [], "name": "ActualTests"},
        ],
    }})
    asserts.equals(env, {"Example": ["Facade", "Testing"]}, modules)

    # A later append must not duplicate the inferred dependency.
    select = scg.new_fn_call("select", {"//:ios": ["@system_sdk//:Foundation"], "//conditions:default": []})
    value = scg.new_expr(select, scg.new_op("+"), ["@system_sdk//:Foundation"])
    normalized = dependency_normalization.normalize(value, "test_")
    asserts.equals(env, '["@system_sdk//:Foundation"]', scg.to_starlark(normalized.value))

    # Two conditional occurrences preserve exclusion branches and nonempty defaults.
    first = scg.new_fn_call("select", {"//:broad": ["//:dep"], "//:specialized": [], "//conditions:default": []})
    second = scg.new_fn_call("select", {"//:other": [], "//conditions:default": ["//:dep"]})
    normalized = dependency_normalization.normalize(scg.new_expr(first, scg.new_op("+"), second), "test_")
    aliases = [h for h in normalized.helpers if h.kind == "alias"]
    asserts.equals(env, 2, len(aliases))
    asserts.equals(env, {"//:broad": ":test_true", "//:specialized": ":test_false", "//conditions:default": ":test_false"}, aliases[0].attrs["actual"].args[0])
    asserts.equals(env, {"//:other": ":test_false", "//conditions:default": ":test_true"}, aliases[1].attrs["actual"].args[0])
    asserts.equals(env, 1, scg.to_starlark(normalized.value).count("//:dep"))
    return unittest.end(env)

regressions_test = unittest.make(_regressions_test)

def _conditional_imports_test(ctx):
    env = unittest.begin(ctx)
    target = _fixture()
    source = """#if os(iOS) || os(tvOS)
import UIKit
#else
import AppKit
#endif
#if targetEnvironment(simulator)
import Dispatch
#endif
#if canImport(Foundation)
import Foundation
#endif
#if DEBUG
import Darwin
#endif
#if canImport(XCTest)
import XCTest
#endif
"""
    repository_ctx = testutils.new_stub_repository_ctx(repo_name = "swiftpkg_example", file_contents = {"Sources/Example/example.swift": source})
    pkg_ctx = pkg_ctxs.new(
        pkg_info = pkginfos.new(name = "Example", path = ".", targets = [target]),
        repo_name = "swiftpkg_example",
        system_sdk_deps = True,
        sdk_modules = {
            "AppKit": [{"condition": "//:macos", "environment": "device", "platform": "macos"}],
            "Darwin": [{"condition": "//:ios", "environment": "device", "platform": "ios"}],
            "Dispatch": [
                {"condition": "//:ios_device", "environment": "device", "platform": "ios"},
                {"condition": "//:ios_sim", "environment": "simulator", "platform": "ios"},
            ],
            "Foundation": [{"condition": "//:macos", "environment": "device", "platform": "macos"}],
            "UIKit": [{"condition": "//:ios", "environment": "device", "platform": "ios"}],
            "XCTest": [{"condition": "//:ios", "environment": "device", "platform": "ios"}],
        },
    )
    deps = system_sdk_deps.for_target(repository_ctx, pkg_ctx, target)
    labels = {(d.value, d.condition): True for d in deps}
    for pair in [("@system_sdk//:UIKit", "//:ios"), ("@system_sdk//:AppKit", "//:macos"), ("@system_sdk//:Dispatch", "//:ios_sim"), ("@system_sdk//:Foundation", "//:macos")]:
        asserts.true(env, pair in labels, labels)
    for pair in [("@system_sdk//:Dispatch", "//:ios_device"), ("@system_sdk//:Darwin", "//:ios"), ("@system_sdk//:XCTest", "//:ios")]:
        asserts.false(env, pair in labels, labels)
    return unittest.end(env)

conditional_imports_test = unittest.make(_conditional_imports_test)

def _resolved_deps_test(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.equals(env, ctx.attr.expected, len(target[DefaultInfo].files.to_list()))
    return analysistest.end(env)

def _settings(broad = False, narrow = False, other = False):
    return {
        str(Label("//swiftpkg/tests:normalization_broad_flag")): broad,
        str(Label("//swiftpkg/tests:normalization_narrow_flag")): narrow,
        str(Label("//swiftpkg/tests:normalization_other_flag")): other,
    }

_default_deps_test = analysistest.make(_resolved_deps_test, attrs = {"expected": attr.int()}, config_settings = _settings())
_overlap_deps_test = analysistest.make(_resolved_deps_test, attrs = {"expected": attr.int()}, config_settings = _settings(broad = True))
_broad_deps_test = analysistest.make(_resolved_deps_test, attrs = {"expected": attr.int()}, config_settings = _settings(broad = True, other = True))
_specialized_deps_test = analysistest.make(_resolved_deps_test, attrs = {"expected": attr.int()}, config_settings = _settings(broad = True, narrow = True, other = True))

def _as_selector(value):
    return select(value.args[0]) if getattr(value, "fn_name", None) == "select" else value

def _normalization_targets():
    for flag in ["broad", "narrow", "other"]:
        bool_flag(name = "normalization_" + flag + "_flag", build_setting_default = False)
    native.config_setting(name = "normalization_broad", flag_values = {":normalization_broad_flag": "true"})
    native.config_setting(name = "normalization_narrow", flag_values = {":normalization_broad_flag": "true", ":normalization_narrow_flag": "true"})
    native.config_setting(name = "normalization_other", flag_values = {":normalization_other_flag": "true"})
    native.filegroup(name = "normalization_payload", srcs = ["system_sdk_tests.bzl"])
    first = scg.new_fn_call("select", {":normalization_broad": [":normalization_payload"], ":normalization_narrow": [], "//conditions:default": []})
    second = scg.new_fn_call("select", {":normalization_other": [], "//conditions:default": [":normalization_payload"]})
    result = dependency_normalization.normalize(scg.new_expr(first, scg.new_op("+"), second), "normalization_")
    for helper in result.helpers:
        if helper.kind == "alias":
            native.alias(name = helper.name, actual = _as_selector(helper.attrs["actual"]))
        elif helper.kind == "config_setting":
            native.config_setting(name = helper.name, **helper.attrs)
        else:
            selects.config_setting_group(name = helper.name, **helper.attrs)
    srcs = []
    for part in result.value.members:
        if getattr(part, "operator", None) != "+":
            srcs = srcs + _as_selector(part)
    native.filegroup(name = "normalized_dependencies", srcs = srcs)
    tests = []
    for name, rule, expected in [
        ("default", _default_deps_test, 1),
        ("overlap", _overlap_deps_test, 1),
        ("broad", _broad_deps_test, 1),
        ("specialized", _specialized_deps_test, 0),
    ]:
        test_name = "normalization_" + name + "_test"
        rule(name = test_name, target_under_test = ":normalized_dependencies", expected = expected)
        tests.append(":" + test_name)
    return tests

def system_sdk_test_suite(name = "system_sdk_tests"):
    unittest.suite("system_sdk_unit_tests", inventory_test, generated_deps_test, regressions_test, conditional_imports_test)
    native.test_suite(name = name, tests = [":system_sdk_unit_tests"] + _normalization_targets())
