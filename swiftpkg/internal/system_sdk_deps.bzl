"""Opt-in SDK dependencies for source targets, using the configured SDK inventory."""

load(":bzl_selects.bzl", "bzl_selects")
load(":objc_files.bzl", "objc_files")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":swift_files.bzl", "swift_files")

_DEVELOPER_MODULES = ["XCTest", "Testing", "XCUIAutomation", "StoreKitTest"]
_OS_PLATFORMS = {"Android": "android", "FreeBSD": "freebsd", "Linux": "linux", "OpenBSD": "openbsd", "WASI": "wasi", "Windows": "windows", "iOS": "ios", "macOS": "macos", "tvOS": "tvos", "visionOS": "visionos", "watchOS": "watchos"}

def _matches(expression, entry, module):
    if expression == None:
        return None
    values = []
    for token in expression:
        if type(token) == "bool":
            values.append(token)
        elif type(token) == "tuple":
            predicate, argument = token
            if predicate == "os" and argument in _OS_PLATFORMS:
                values.append(entry["platform"] == _OS_PLATFORMS[argument])
            elif predicate == "targetEnvironment" and argument == "simulator" and "environment" in entry:
                values.append(entry["environment"] == "simulator")
            elif predicate == "canImport" and argument == module:
                # The inventory entry proves this imported SDK module exists for
                # this exact Xcode and SDK. Unrelated canImport remains unknown.
                values.append(True)
            else:
                return None
        elif token == "!":
            values.append(not values.pop())
        else:
            right = values.pop()
            left = values.pop()
            values.append(left and right if token == "&&" else left or right)
    return values[0]

def _scan_prefix(contents):
    if "\\\n" in contents or "\\\r\n" in contents:
        return contents
    last = max(contents.rfind("import"), contents.rfind("include"))
    if last < 0:
        return ""
    end = contents.find("\n", last)
    if end < 0:
        return contents
    line = contents[last:end]

    # Multiline directives and splices keep the complete input. An unfinished
    # trailing literal/comment can safely remain open when there is no later
    # import/include token to discover.
    if "\\" not in line and (";" in line or ">" in line):
        return contents[:end + 1]
    return contents

def _digit_separator(contents, idx):
    if idx + 1 >= len(contents) or not contents[idx + 1].isalnum():
        return False
    start = idx
    for pos in range(idx - 1, -1, -1):
        if not (contents[pos].isalnum() or contents[pos] in "_.'"):
            break
        start = pos
    return start < idx and contents[start].isdigit()

def _next_unspliced(contents, start):
    skip_to = start
    for pos in range(start, len(contents)):
        if pos < skip_to:
            continue
        if contents[pos:pos + 2] == "\\\n":
            skip_to = pos + 2
        elif contents[pos:pos + 3] == "\\\r\n":
            skip_to = pos + 3
        else:
            return pos
    return len(contents)

def _clang_imports(contents):
    if "import" not in contents and "include" not in contents and "\\\n" not in contents and "\\\r\n" not in contents:
        return {}

    contents = _scan_prefix(contents)

    # Preserve newlines while masking comments and C/ObjC/C++ literals. In
    # particular, comment delimiters inside quoted/raw strings are not comments.
    pieces = []
    state = "code"
    closing = ""
    skip_to = 0
    splice_to = 0
    for idx in range(len(contents)):
        char = contents[idx]

        # Translation phase two removes escaped newlines before tokenization.
        # Raw strings are masked as a whole and preserve their delimiters.
        if idx < splice_to:
            continue
        if state != "raw" and char == "\\":
            if contents[idx + 1:idx + 2] == "\n":
                splice_to = idx + 2
                continue
            if contents[idx + 1:idx + 3] == "\r\n":
                splice_to = idx + 3
                continue
        if char == "\n":
            pieces.append("\n")
            if state in ["line", "quote"]:
                state = "code"
        if idx < skip_to:
            continue
        next_idx = _next_unspliced(contents, idx + 1) if char in "/*R" else idx + 1
        pair = char + contents[next_idx:next_idx + 1]
        if state == "line":
            continue
        if state == "block":
            if pair == "*/":
                state = "code"
                skip_to = next_idx + 1
            continue
        if state == "raw":
            if contents[idx:idx + len(closing)] == closing:
                state = "code"
                skip_to = idx + len(closing)
            continue
        if state == "quote":
            if char == "\\":
                skip_to = _next_unspliced(contents, idx + 1) + 1
            elif char == closing:
                state = "code"
            continue
        if char == "\n":
            continue
        if pair == "//":
            state = "line"
            skip_to = next_idx + 1
        elif pair == "/*":
            state = "block"
            pieces.append(" ")
            skip_to = next_idx + 1
        elif pair == 'R"':
            opening = contents.find("(", next_idx + 1, next_idx + 18)
            if opening >= 0:
                closing = ")" + contents[next_idx + 1:opening] + '"'
                state = "raw"
                skip_to = opening + 1
            else:
                pieces.append(char)
        elif char in ['"', "'"] and not (char == "'" and _digit_separator(contents, idx)):
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
        imported["Foundation"] = [[]]
    srcs = pkginfo_targets.srcs(target)
    if target.clang_src_info:
        srcs = target.clang_src_info.explicit_srcs + target.clang_src_info.hdrs + target.clang_src_info.textual_hdrs
    for src in sorted({s: True for s in srcs}):
        if src.endswith(".swift"):
            for imp in swift_files.collect_imports(repository_ctx.read(src)):
                imported.setdefault(imp.module_name, []).append(imp.conditions)
        elif src.endswith((".m", ".mm", ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl")):
            for module in _clang_imports(repository_ctx.read(src)):
                imported.setdefault(module, []).append([])

    # A same-named package module or alias is not an SDK dependency.
    local_modules = {t.c99name: True for t in pkg_ctx.pkg_info.targets}
    local_modules.update({name: True for name in getattr(pkg_ctx, "module_alias_flags", {})})
    local_modules.update({name: True for name in getattr(pkg_ctx, "module_alias_flags", {}).values()})
    local_modules.update({name: True for name in getattr(pkg_ctx, "dependency_modules", {}).get(target.name, [])})
    if target.type != "test":
        local_modules.update({module: True for module in _DEVELOPER_MODULES})
    deps = {}
    for module in sorted(imported):
        if module in local_modules:
            continue
        for entry in inventory.get(module, []):
            if any([all([_matches(expr, entry, module) == expected for expr, expected in clauses]) for clauses in imported[module]]):
                deps[(module, entry["condition"])] = None

    if target.linker_settings:
        for setting in target.linker_settings.linked_frameworks:
            condition = setting.condition
            for module in setting.values:
                if module in local_modules:
                    continue
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
    scan_prefix = _scan_prefix,
)
