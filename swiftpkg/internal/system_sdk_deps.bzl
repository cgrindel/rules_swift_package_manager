"""Opt-in SDK dependencies for source targets, using the configured SDK inventory."""

load(":bzl_selects.bzl", "bzl_selects")
load(":objc_files.bzl", "objc_files")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":swift_files.bzl", "swift_files")

def _clang_imports(contents):
    if "import" not in contents and "include" not in contents:
        return {}

    # Preserve newlines while masking comments and C/ObjC/C++ literals. In
    # particular, comment delimiters inside quoted/raw strings are not comments.
    pieces = []
    state = "code"
    closing = ""
    skip_to = 0
    for idx in range(len(contents)):
        char = contents[idx]
        if char == "\n":
            pieces.append("\n")
            if state == "line" and (idx == 0 or contents[idx - 1] != "\\"):
                state = "code"
        if idx < skip_to:
            continue
        pair = contents[idx:idx + 2]
        if state == "line":
            continue
        if state == "block":
            if pair == "*/":
                state = "code"
                skip_to = idx + 2
            continue
        if state == "raw":
            if contents[idx:idx + len(closing)] == closing:
                state = "code"
                skip_to = idx + len(closing)
            continue
        if state == "quote":
            if char == "\\":
                skip_to = idx + 2
            elif char == closing:
                state = "code"
            continue
        if char == "\n":
            continue
        if pair == "//":
            state = "line"
        elif pair == "/*":
            state = "block"
            pieces.append(" ")
            skip_to = idx + 2
        elif pair == 'R"':
            opening = contents.find("(", idx + 2, idx + 19)
            if opening >= 0:
                closing = ")" + contents[idx + 2:opening] + '"'
                state = "raw"
                skip_to = opening + 1
            else:
                pieces.append(char)
        elif char in ['"', "'"]:
            state = "quote"
            closing = char
            pieces.append(" ")
        else:
            pieces.append(char)
    lines = "".join(pieces).splitlines()
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
                if not imp.is_conditional:
                    imported[imp.module_name] = True
        elif src.endswith((".m", ".mm", ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl")):
            imported.update(_clang_imports(repository_ctx.read(src)))

    # A same-named package module or alias is not an SDK dependency.
    local_modules = {t.c99name: True for t in pkg_ctx.pkg_info.targets}
    local_modules.update({name: True for name in getattr(pkg_ctx, "module_alias_flags", {})})
    local_modules.update({name: True for name in getattr(pkg_ctx, "module_alias_flags", {}).values()})
    local_modules.update({name: True for name in getattr(pkg_ctx, "dependency_modules", {}).get(target.name, [])})
    deps = {}
    for module in sorted(imported):
        if module in local_modules:
            continue
        for entry in inventory.get(module, []):
            deps[(module, entry["condition"])] = None

    if target.linker_settings:
        for setting in target.linker_settings.linked_frameworks:
            condition = setting.condition
            for module in setting.values:
                for entry in inventory.get(module, []):
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
    clang_imports = _clang_imports,
)
