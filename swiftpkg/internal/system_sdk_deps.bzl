"""Opt-in SDK dependencies for source targets, using the configured SDK inventory."""

load("//config_settings/spm/platform:platforms.bzl", "platforms")
load("//config_settings/spm/platform_configuration:platform_configurations.bzl", "platform_configurations")
load(":bzl_selects.bzl", "bzl_selects")
load(":objc_files.bzl", "objc_files")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":swift_files.bzl", "swift_files")

def _clang_imports(contents):
    # Reuse the existing ObjC import parser, including its module/header syntax.
    # Remove comments first so documentation and disabled sample code do not
    # invent dependencies. Quoted local includes are deliberately ignored.
    lines = []
    block = False
    for line in contents.splitlines():
        pieces = []
        skip_to = 0
        for idx in range(len(line)):
            if idx < skip_to:
                continue
            pair = line[idx:idx + 2]
            if block:
                if pair == "*/":
                    block = False
                    skip_to = idx + 2
            elif pair == "//":
                break
            elif pair == "/*":
                block = True
                skip_to = idx + 2
                pieces.append(" ")
            else:
                pieces.append(line[idx])
        lines.append("".join(pieces))
    imports = {}
    for line in lines:
        line = line.strip()
        if line.startswith("#"):
            directive = line[1:].lstrip()
            if directive.startswith("include"):
                line = "#import" + directive[len("include"):]
        elif not line.startswith("@import "):
            continue
        module = objc_files.parse_for_import(line)
        if module:
            imports[module.split("/")[0].split(".")[0]] = True
    return imports

def _for_target(repository_ctx, pkg_ctx, target):
    if not getattr(pkg_ctx, "system_sdk_deps", False):
        return []
    inventory = getattr(pkg_ctx, "sdk_modules", {})
    if not inventory:
        return []
    imported = {}
    if target.resources and (target.swift_src_info or target.objc_src_info):
        # The generated Bundle.module accessors import Foundation.
        imported["Foundation"] = True
    srcs = pkginfo_targets.srcs(target)
    if target.clang_src_info:
        srcs = target.clang_src_info.explicit_srcs + target.clang_src_info.hdrs + target.clang_src_info.textual_hdrs
    for src in sorted({s: True for s in srcs}):
        if src.endswith(".swift"):
            for imp in swift_files.collect_imports(repository_ctx.read(src)):
                imported[imp.module_name] = True
        elif src.endswith((".m", ".mm", ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl")):
            imported.update(_clang_imports(repository_ctx.read(src)))

    # A same-named package module or alias is not an SDK dependency.
    local_modules = {t.c99name: True for t in pkg_ctx.pkg_info.targets}
    local_modules.update({name: True for name in getattr(pkg_ctx, "module_alias_flags", {})})
    local_modules.update({name: True for name in getattr(pkg_ctx, "module_alias_flags", {}).values()})
    deps = {}
    for module in sorted(imported):
        if module in local_modules:
            continue
        for platform in inventory.get(module, []):
            deps[(module, platforms.label(platform))] = None

    if target.linker_settings:
        for setting in target.linker_settings.linked_frameworks:
            condition = setting.condition
            for module in setting.values:
                for platform in inventory.get(module, []):
                    if condition and condition.platforms and platform not in [p.lower() for p in condition.platforms]:
                        continue
                    label = platforms.label(platform)
                    if condition and condition.configuration:
                        # Imports already provide this module in all configurations.
                        if (module, label) in deps:
                            continue
                        label = platform_configurations.label(platform, condition.configuration)
                    deps[(module, label)] = None
    return [
        bzl_selects.new(
            value = "@system_sdk//:" + module,
            # Separate platform+configuration selects from plain platform selects;
            # each can contribute dependencies without specializing the other away.
            kind = "sdk_configuration" if "/platform_configuration:" in condition else "sdk",
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
    clang_imports = _clang_imports,
)
