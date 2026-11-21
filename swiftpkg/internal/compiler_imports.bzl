"""Consume committed compiler prescans; never execute Swift during fetching."""

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
        "-frontend",
        "-scan-dependencies",
        "-import-prescan",
        "-module-name",
        pkg_ctx.module_aliases.get(target.c99name, target.c99name),
        "-sdk",
        "${SDK}",
        "-target",
        scan["targets"][sdk],
        "-module-cache-path",
        "${MODULE_CACHE}",
        "-DSWIFT_PACKAGE",
    ]
    args.append("-O" if configuration == "release" else "-Onone")
    if configuration != "release":
        args.append("-DDEBUG")
    for name in (scan.get("defines") or []) + pkg_ctx.pkg_info.enabled_traits:
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

def _validate_inputs(ctx, inputs):
    """Check source bytes using Bazel's native checksum verifier, without tools."""
    for source, digest in sorted(inputs.items()):
        if source.startswith("/") or ".." in source.split("/"):
            fail("Invalid relative source path in SDK cache: " + source)

        # A checksum-only download could reuse old bytes from the download cache.
        # Include the exact current contents in canonical_id, so that a changed
        # source must be read and verified again. No network request is involved.
        contents = ctx.read(source)
        path = str(ctx.path(source))
        url_path = path.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("?", "%3F")
        result = ctx.download(
            url = "file://" + url_path,
            output = ".rspm_cached_input",
            sha256 = digest,
            canonical_id = "rspm-source-cache\n" + contents,
            allow_fail = True,
        )
        ctx.delete(".rspm_cached_input")
        if not result.success:
            fail("SDK source cache is stale for {}. Regenerate with bazel run @rules_swift_package_manager//swiftpkg:update_sdk_cache -- --request <profiles.json> --package <root-package> --output <cache.json>.".format(source))

def _scan(ctx, pkg_ctx, target, dependency_modules):
    inventory = pkg_ctx.sdk_modules
    package = inventory.scan.get("packages", {}).get(pkg_ctx.repo_name)
    cached = package.get("targets", {}).get(target.name) if package else None
    if cached == None:
        fail("Missing committed SDK prescan for {}/{}. Run bazel run @rules_swift_package_manager//swiftpkg:update_sdk_cache -- --request <profiles.json> --package <root-package> --output <cache.json>.".format(pkg_ctx.repo_name, target.name))
    if sorted(cached["inputs"]) != sorted(pkginfo_targets.srcs(target)):
        fail("SDK cache source list changed for {}; regenerate the cache.".format(target.name))
    _validate_inputs(ctx, cached["inputs"])
    results = []
    for _, entry in sorted(inventory.conditions.items()):
        sdk = entry["sdk"]
        for configuration in sorted(entry["configurations"]):
            args = _arguments(pkg_ctx, target, entry, configuration, dependency_modules.get(entry["platform"], []))
            records = [r for r in cached["scans"] if r["sdk"] == sdk and r["configuration"] == configuration]
            if len(records) != 1 or records[0]["arguments"] != args:
                fail("SDK cache compiler settings changed for {} ({}, {}); regenerate the cache. Expected arguments: {}".format(target.name, sdk, configuration, args))
            record = records[0]
            results.append({
                "condition": entry["configurations"][configuration],
                "configuration": configuration,
                "imports": record["imports"],
                "sdk": sdk,
                "warnings": record["warnings"],
            })
    return results

compiler_imports = struct(arguments = _arguments, scan = _scan, validate_inputs = _validate_inputs)
