"""Opt-in SDK dependencies for source targets, using the configured SDK inventory."""

load(":bzl_selects.bzl", "bzl_selects")
load(":clang_files.bzl", "clang_files")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":swift_files.bzl", "swift_files")
load(":system_sdk_modules.bzl", "system_sdk_modules")

_DEVELOPER_MODULES = ["XCTest", "Testing", "XCUIAutomation", "StoreKitTest"]

def _source_imports(repository_ctx, target):
    imported = {}
    if target.resources and (target.swift_src_info or target.objc_src_info):
        # The generated Bundle.module accessors import Foundation.
        imported["Foundation"] = [[]]
    srcs = pkginfo_targets.srcs(target)
    if target.clang_src_info:
        srcs = target.clang_src_info.explicit_srcs + target.clang_src_info.hdrs + target.clang_src_info.textual_hdrs
    for src in sorted({s: True for s in srcs}):
        if src.endswith(".swift"):
            for imp in swift_files.collect_imports(repository_ctx.read(src)):
                imported.setdefault(imp.module_name, []).append(imp.conditions)
        elif src.endswith((".m", ".mm", ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl")):
            for module in clang_files.imports(repository_ctx.read(src)):
                imported.setdefault(module, []).append([])
    return imported

def _excluded_modules(pkg_ctx, target):
    # Package modules, aliases, and resolved dependency modules take precedence.
    local_modules = {t.c99name: True for t in pkg_ctx.pkg_info.targets}
    local_modules.update({name: True for name in getattr(pkg_ctx, "module_alias_flags", {})})
    local_modules.update({name: True for name in getattr(pkg_ctx, "module_alias_flags", {}).values()})
    local_modules.update({name: True for name in getattr(pkg_ctx, "dependency_modules", {}).get(target.name, [])})
    if target.type != "test":
        local_modules.update({module: True for module in _DEVELOPER_MODULES})
    return local_modules

def _source_deps(inventory, imported, excluded):
    deps = {}
    for module in sorted(imported):
        if module in excluded:
            continue
        for entry in system_sdk_modules.entries(inventory, module):
            if any([all([swift_files.matches(expr, entry, module) == expected for expr, expected in clauses]) for clauses in imported[module]]):
                deps[(module, entry["condition"])] = None
    return deps

def _add_manifest_deps(inventory, target, excluded, deps):
    if target.linker_settings:
        for setting in target.linker_settings.linked_frameworks:
            condition = setting.condition
            for module in setting.values:
                if module in excluded:
                    continue
                for entry in system_sdk_modules.entries(inventory, module):
                    if condition and condition.platforms and entry["platform"] not in [p.lower() for p in condition.platforms]:
                        continue
                    label = entry["condition"]
                    if condition and condition.configuration:
                        if (module, label) in deps:
                            continue
                        label = entry["configurations"][condition.configuration]
                    else:
                        # Unconditional availability subsumes all build configurations,
                        # regardless of the order of linkedFramework declarations.
                        for config_label in entry["configurations"].values():
                            deps.pop((module, config_label), None)
                    deps[(module, label)] = None

def _for_target(repository_ctx, pkg_ctx, target):
    if not getattr(pkg_ctx, "system_sdk_deps", False):
        return []
    inventory = getattr(pkg_ctx, "sdk_modules", {})
    if not inventory or (type(inventory) == "struct" and not inventory.modules):
        return []
    excluded = _excluded_modules(pkg_ctx, target)
    deps = _source_deps(inventory, _source_imports(repository_ctx, target), excluded)
    _add_manifest_deps(inventory, target, excluded, deps)
    return [
        bzl_selects.new(
            value = "@system_sdk//:" + module,
            # Separate platform+configuration selects from plain platform selects;
            # each can contribute dependencies without specializing the other away.
            kind = "sdk_configuration" if condition.endswith(("_debug", "_release")) else "sdk",
            condition = condition,
        )
        for module, condition in sorted(deps)
    ]

def _merge(deps, inferred):
    # Manual unconditional dependencies take precedence and should not appear a
    # second time in a platform select. Leave existing dependency behavior intact.
    explicit = {dep: True for dep in deps if type(dep) == "string"}
    return deps + [dep for dep in inferred if dep.value not in explicit]

system_sdk_deps = struct(
    for_target = _for_target,
    merge = _merge,
    clang_imports = clang_files.imports,
    scan_prefix = clang_files.scan_prefix,
)
