"""Swift compiler import prescans for explicitly configured SDK profiles."""

load(":pkginfo_targets.bzl", "pkginfo_targets")

def _active(setting, platform, configuration):
    condition = setting.condition
    return not condition or (
        (not condition.platforms or platform in [p.lower() for p in condition.platforms]) and
        (not condition.configuration or condition.configuration == configuration)
    )

def _arguments(pkg_ctx, target, entry, configuration, available_modules):
    scan = pkg_ctx.sdk_modules.scan
    sdk = entry["sdk"]
    args = [
        scan["swiftc"],
        "-frontend",
        "-scan-dependencies",
        "-import-prescan",
        "-module-name",
        pkg_ctx.module_aliases.get(target.c99name, target.c99name),
        "-sdk",
        scan["sdks"][sdk],
        "-target",
        scan["targets"][sdk],
        "-module-cache-path",
        ".rspm_sdk_module_cache",
        "-DSWIFT_PACKAGE",
    ]
    args.append("-O" if configuration == "release" else "-Onone")
    if configuration != "release":
        args.append("-DDEBUG")
    for name in scan.get("defines", []) + pkg_ctx.pkg_info.enabled_traits:
        args.append("-D" + name)
    importable = {name: True for name in available_modules}
    importable.update({pkg_ctx.module_alias_flags.get(name, name): True for name in available_modules})
    for name in sorted(importable):
        # A prescan can recognize package modules without compiling them. Never
        # fabricate SDK availability: the selected compiler/SDK establishes it.
        args.extend(["-module-can-import", name])
    for original, renamed in sorted(pkg_ctx.module_alias_flags.items()):
        args.extend(["-module-alias", original + "=" + renamed])
    settings = target.swift_settings
    if not settings or not settings.language_modes:
        if pkg_ctx.pkg_info.language_mode:
            args.extend(["-swift-version", pkg_ctx.pkg_info.language_mode])
    if settings:
        for setting in settings.defines:
            if _active(setting, entry["platform"], configuration):
                args.extend(["-D" + value for value in setting.values])
        for setting in settings.unsafe_flags:
            if _active(setting, entry["platform"], configuration) and setting.values:
                fail("SDK inference cannot reproduce unsafe Swift flags for {}. Use manual SDK deps and disable system_sdk_deps for this package.".format(target.name))
        for field, flag in [
            ("language_modes", "-swift-version"),
            ("experimental_features", "-enable-experimental-feature"),
            ("upcoming_features", "-enable-upcoming-feature"),
        ]:
            for setting in getattr(settings, field):
                if _active(setting, entry["platform"], configuration):
                    for value in setting.values:
                        args.extend([flag, value])
    args.extend(sorted(pkginfo_targets.srcs(target)))
    return args

def _version_warnings(stderr, package_modules):
    # Let Swift parse and evaluate #if/#elseif, including comments and inactive
    # branches. -module-can-import supplies names, not package module versions.
    warnings = []
    for line in stderr.splitlines():
        _, sep, diagnostic = line.partition(": warning: ")
        if not sep:
            continue
        for prefix in ["cannot find user version number for module '", "cannot find user version number for Clang module '"]:
            if diagnostic.startswith(prefix):
                module = diagnostic[len(prefix):].partition("'")[0]
                if module in package_modules:
                    warnings.append({"message": line, "module": module})
    return warnings

def _scan(ctx, pkg_ctx, target, dependency_modules):
    inventory = pkg_ctx.sdk_modules
    scan = inventory.scan
    results = []
    cache = {}
    for _, entry in sorted(inventory.conditions.items()):
        sdk = entry["sdk"]
        for configuration in sorted(entry["configurations"]):
            available = dependency_modules.get(entry["platform"], [])
            args = _arguments(pkg_ctx, target, entry, configuration, available)

            # Match always_include_developer_search_paths on generated libraries.
            sdk_developer = ctx.path(scan["sdks"][sdk]).dirname.dirname
            framework_dirs = [str(sdk_developer) + "/Library/Frameworks"]
            if entry["platform"] != "macos":
                framework_dirs.append(scan["sdks"][sdk] + "/Developer/Library/Frameworks")
            for path in framework_dirs:
                if ctx.path(path).exists:
                    args.extend(["-F", path])
            swift_developer_lib = str(sdk_developer) + "/usr/lib"
            if ctx.path(swift_developer_lib).exists:
                args.extend(["-I", swift_developer_lib])
            key = tuple(args)
            if key not in cache:
                ctx.report_progress("Scanning Swift imports: {} ({}, {})".format(target.name, sdk, configuration))
                result = ctx.execute(args, environment = scan["environment"])
                if result.return_code:
                    fail("Swift import prescan failed for {} ({}, {}):\n{}\nUse manual SDK deps and disable inference for unsupported configurations.".format(target.name, sdk, configuration, result.stderr))
                warnings = _version_warnings(result.stderr, available + [pkg_ctx.module_alias_flags.get(name, name) for name in available])
                decoded = json.decode(result.stdout)
                if type(decoded) != "dict" or type(decoded.get("imports")) != "list" or not all([type(name) == "string" for name in decoded["imports"]]):
                    fail("Unsupported Swift import prescan output for " + target.name)
                cache[key] = struct(imports = sorted({name: True for name in decoded["imports"]}), warnings = warnings)
            results.append({
                "condition": entry["configurations"][configuration],
                "configuration": configuration,
                "imports": cache[key].imports,
                "sdk": sdk,
                "warnings": cache[key].warnings,
            })
    return results

compiler_imports = struct(arguments = _arguments, scan = _scan, version_warnings = _version_warnings)
