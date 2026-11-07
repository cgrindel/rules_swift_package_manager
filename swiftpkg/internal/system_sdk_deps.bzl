"""Opt-in SDK dependencies for source targets, using the configured SDK inventory."""

load(":bzl_selects.bzl", "bzl_selects")
load(":clang_files.bzl", "clang_files")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":system_sdk_labels.bzl", "system_sdk_labels")

def _entries(inventory, module):
    # The inventory provider supplies this compact package-context interface.
    return [inventory.conditions[i] for i in inventory.modules.get(module, [])]

def _source_imports(repository_ctx, target):
    imported = {}
    if target.resources and (target.swift_src_info or target.objc_src_info):
        # The generated Bundle.module accessors import Foundation.
        imported["Foundation"] = True
    srcs = pkginfo_targets.srcs(target)
    if target.clang_src_info:
        srcs = target.clang_src_info.explicit_srcs + target.clang_src_info.hdrs + target.clang_src_info.textual_hdrs
    for src in sorted({s: True for s in srcs}):
        if src.endswith((".m", ".mm", ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl")):
            for module in clang_files.imports(repository_ctx.read(src)):
                imported[module] = True
    return imported

def _excluded_modules(pkg_ctx, target):
    # Alias flags apply to this package's compilation. Resolved module names
    # below are platform-scoped, including names supplied by Clang module maps.
    aliases = pkg_ctx.module_alias_flags
    unconditional = {name: True for name in aliases}
    unconditional.update({name: True for name in aliases.values()})
    return struct(
        unconditional = unconditional,
        platforms = pkg_ctx.dependency_modules.get(target.name, {}),
    )

def _excluded(excluded, module, entry):
    return module in excluded.unconditional or module in excluded.platforms.get(entry["platform"], [])

def _source_deps(inventory, imported, excluded, scans):
    deps = {}
    for module in sorted(imported):
        for entry in _entries(inventory, module):
            if not _excluded(excluded, module, entry):
                deps[(module, entry["condition"])] = "sdk"
    scanned_modules = {module: True for record in scans for module in record["imports"]}
    for module in sorted(scanned_modules):
        for entry in _entries(inventory, module):
            if _excluded(excluded, module, entry):
                continue
            matches = [record for record in scans if record["sdk"] == entry["sdk"] and module in record["imports"]]
            if not matches:
                continue
            if len(matches) == len(entry["configurations"]):
                deps[(module, entry["condition"])] = "sdk"
            elif (module, entry["condition"]) not in deps:
                for record in matches:
                    deps[(module, record["condition"])] = "sdk_configuration"
    return deps

def _add_manifest_deps(inventory, target, excluded, deps):
    if target.linker_settings:
        for setting in target.linker_settings.linked_frameworks:
            condition = setting.condition
            for module in setting.values:
                for entry in _entries(inventory, module):
                    if _excluded(excluded, module, entry):
                        continue
                    if condition and condition.platforms and entry["platform"] not in [p.lower() for p in condition.platforms]:
                        continue
                    label = entry["condition"]
                    kind = "sdk"
                    if condition and condition.configuration:
                        if (module, label) in deps:
                            continue
                        label = entry["configurations"][condition.configuration]
                        kind = "sdk_configuration"
                    else:
                        # Unconditional availability subsumes all build configurations,
                        # regardless of the order of linkedFramework declarations.
                        for config_label in entry["configurations"].values():
                            deps.pop((module, config_label), None)
                    deps[(module, label)] = kind

def _for_target(repository_ctx, pkg_ctx, target):
    if not pkg_ctx.system_sdk_deps:
        return []
    inventory = pkg_ctx.sdk_modules
    excluded = _excluded_modules(pkg_ctx, target)
    deps = _source_deps(inventory, _source_imports(repository_ctx, target), excluded, (pkg_ctx.source_scans or {}).get(target.name, []))
    _add_manifest_deps(inventory, target, excluded, deps)
    return [
        bzl_selects.new(
            value = "@system_sdk//:" + module,
            # Separate platform+configuration selects from plain platform selects;
            # each can contribute dependencies without specializing the other away.
            kind = deps[(module, condition)],
            condition = condition,
        )
        for module, condition in sorted(deps)
    ]

def _merge(deps, inferred):
    # Manual unconditional dependencies take precedence and should not appear a
    # second time in a platform select. Leave existing dependency behavior intact.
    explicit = {system_sdk_labels.key(dep): True for dep in deps if type(dep) == "string"}
    return deps + [dep for dep in inferred if system_sdk_labels.key(dep.value) not in explicit]

system_sdk_deps = struct(
    for_target = _for_target,
    merge = _merge,
)
