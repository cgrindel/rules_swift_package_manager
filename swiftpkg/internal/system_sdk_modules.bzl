"""Shared, lazy adapter for rules_swift's generated SDK aliases."""

_SDK_BUILD = Label("@system_sdk//:BUILD.bazel")
_INVENTORY = Label("@rspm_sdk_inventory//:modules.json")
_SDK_PLATFORMS = {
    "AppleTVOS": "tvos",
    "AppleTVSimulator": "tvos",
    "MacOSX": "macos",
    "WatchOS": "watchos",
    "WatchSimulator": "watchos",
    "XROS": "visionos",
    "XRSimulator": "visionos",
    "iPhoneOS": "ios",
    "iPhoneSimulator": "ios",
}
_GROUPS = ["all_modules", "implicit_modules", "all_cross_import_overlays"]

def _aliases(contents):
    result = {}
    name = None
    branches = None
    state = None
    for raw_line in contents.splitlines():
        line = raw_line.strip()
        if state == None:
            if line == "alias(":
                state = "name"
            elif line.startswith("alias("):
                return None
            continue
        if state == "name":
            if not (line.startswith('name = "') and line.endswith('",')):
                return None
            name = line[len('name = "'):-2]
            branches = {}
            state = "select"
        elif state == "select":
            if line != "actual = select({":
                return None
            state = "branches"
        elif state == "branches":
            if line == "}),":
                state = "end"
            elif line.startswith('"') and line.endswith('",'):
                parts = line[1:-2].split('\": \"')
                if len(parts) != 2 or any(['"' in p or "\\" in p for p in parts]):
                    return None
                branches[parts[0]] = parts[1]
            else:
                return None
        elif state == "end":
            if line != ")" or name in result:
                return None
            result[name] = branches
            state = None
    return result if state == None else None

def _inventory(hub, xcodes):
    """Preserve each Xcode/SDK branch, instead of intersecting installations."""
    result = {}
    for module, branches in hub.items():
        if module in _GROUPS or module.endswith("_clang"):
            continue
        entries = []
        for xcode_condition, actual in sorted(branches.items()):
            repo, sep, target = actual.partition("//:")
            if not sep or not repo.startswith("@system_sdk_xcode_") or target != module:
                return None
            if not xcode_condition.startswith(":xcode_"):
                return None
            aliases = xcodes.get(repo, {}).get(module, {})
            for sdk_condition in sorted(aliases):
                sdk = sdk_condition.removeprefix(":").removesuffix("_sdk")
                if sdk not in _SDK_PLATFORMS:
                    return None
                entries.append({
                    "condition": xcode_condition[1:] + "_" + sdk,
                    "environment": "simulator" if sdk.endswith("Simulator") else "device",
                    "platform": _SDK_PLATFORMS[sdk],
                    "sdk_condition": sdk_condition,
                    "sdk_repo": repo,
                    "xcode_condition": xcode_condition,
                })
        if entries:
            result[module] = entries
    return result

def _sdk_constraints(contents):
    # Upstream marks these settings private, so reproduce their actual constraint
    # lists in the shared repo. Never infer availability from these lists alone.
    result = {}
    for block in contents.split("\nconfig_setting(\n")[1:]:
        body, separator, _ = block.partition("\n)")
        if not separator:
            return None
        name = None
        constraints = []
        in_constraints = False
        for raw_line in body.splitlines():
            line = raw_line.strip()
            if line.startswith('name = "') and line.endswith('",'):
                name = line[len('name = "'):-2]
            elif line == "constraint_values = [":
                in_constraints = True
            elif line == "]," and in_constraints:
                in_constraints = False
            elif in_constraints and line.startswith('"') and line.endswith('",'):
                value = line[1:-2]
                if not value.startswith(("@platforms//os:", "@apple_support//constraints:")):
                    return None
                constraints.append(str(Label(value)))
            elif line == 'visibility = ["//visibility:private"],':
                continue
            else:
                return None
        if not name or not name.endswith("_sdk") or not constraints or in_constraints:
            return None
        result[":" + name] = constraints
    return result

def _unsupported(reason):
    return struct(modules = {}, constraints = {}, diagnostic = reason)

def _warn(reason):
    # buildifier: disable=print
    print("WARNING: SDK inference is disabled: {}. Use target_deps. No partial inventory was used.".format(reason))

def _read_upstream(repository_ctx):
    canonical = _SDK_BUILD.repo_name

    # There is no API for resolving a label through another repository's mapping.
    # Only standard extension-owned hubs have this known sibling mapping. In
    # particular, do not derive sibling names for override_repo replacements.
    if not canonical.endswith("+system_sdk+system_sdk"):
        return _unsupported("overridden rules_swift SDK repository mapping")
    prefix = canonical[:-len("system_sdk")]
    hub = _aliases(repository_ctx.read(_SDK_BUILD))
    if hub == None:
        return _unsupported("unsupported rules_swift SDK hub alias format")
    xcodes = {}
    constraints = {}
    for branches in hub.values():
        for actual in branches.values():
            repo, sep, _ = actual.partition("//:")
            if not sep or not repo.startswith("@system_sdk_xcode_"):
                return _unsupported("unsupported rules_swift SDK hub target mapping")
            if repo in xcodes:
                continue
            label = Label("@@{}{}//:BUILD.bazel".format(prefix, repo[1:]))
            contents = repository_ctx.read(label)
            aliases = _aliases(contents)
            sdk_constraints = _sdk_constraints(contents)
            if aliases == None or sdk_constraints == None:
                return _unsupported("unsupported rules_swift Xcode SDK aliases or constraints in " + repo)
            xcodes[repo] = aliases
            constraints[repo] = sdk_constraints
    inventory = _inventory(hub, xcodes)
    if inventory == None:
        return _unsupported("unsupported rules_swift Xcode or SDK alias condition")
    for entries in inventory.values():
        if any([e["sdk_condition"] not in constraints[e["sdk_repo"]] for e in entries]):
            return _unsupported("missing rules_swift SDK constraint definition")
    return struct(modules = inventory, constraints = constraints, diagnostic = "")

def _repo_impl(repository_ctx):
    upstream = _read_upstream(repository_ctx)
    modules = {}
    conditions = {}
    sdk_settings = {}
    condition_ids = {}
    condition_table = {}
    if upstream.diagnostic:
        _warn(upstream.diagnostic)
    else:
        for module, entries in upstream.modules.items():
            modules[module] = []
            for entry in entries:
                name = entry["condition"]
                if name in condition_ids:
                    modules[module].append(condition_ids[name])
                    continue
                condition_id = str(len(condition_ids))
                condition_ids[name] = condition_id
                modules[module].append(condition_id)
                sdk_name = name + "_sdk"
                sdk_settings[sdk_name] = upstream.constraints[entry["sdk_repo"]][entry["sdk_condition"]]
                match_all = [
                    str(_SDK_BUILD.same_package_label(entry["xcode_condition"][1:])),
                    ":" + sdk_name,
                ]
                conditions[name] = match_all
                configurations = {}
                for config in ["debug", "release"]:
                    config_name = name + "_" + config
                    conditions[config_name] = match_all + [str(Label("//config_settings/spm/configuration:" + config))]
                    configurations[config] = "@@{}//:{}".format(repository_ctx.name, config_name)
                condition_table[condition_id] = {
                    "condition": "@@{}//:{}".format(repository_ctx.name, name),
                    "configurations": configurations,
                    "environment": entry["environment"],
                    "platform": entry["platform"],
                }
    build = [
        'load("@bazel_skylib//lib:selects.bzl", "selects")',
        'package(default_visibility = ["//visibility:public"])',
        'exports_files(["modules.json"])',
    ]
    for name, constraints in sorted(sdk_settings.items()):
        build.append("config_setting(name = {}, constraint_values = {})".format(repr(name), repr(constraints)))
    for name, match_all in sorted(conditions.items()):
        build.append("selects.config_setting_group(name = {}, match_all = {})".format(repr(name), repr(match_all)))
    repository_ctx.file("BUILD.bazel", "\n".join(build) + "\n")
    repository_ctx.file("modules.json", json.encode({
        "conditions": condition_table,
        "diagnostic": upstream.diagnostic,
        "modules": modules,
    }))

_sdk_inventory_repo = repository_rule(implementation = _repo_impl)

def _extension_impl(_module_ctx):
    _sdk_inventory_repo(name = "rspm_sdk_inventory")

sdk_inventory = module_extension(implementation = _extension_impl)

def _decode(contents):
    metadata = json.decode(contents)
    return struct(
        modules = metadata["modules"],
        conditions = metadata["conditions"],
        diagnostic = metadata["diagnostic"],
    )

def _entries(inventory, module):
    if type(inventory) == "dict":
        return inventory.get(module, [])
    return [inventory.conditions[i] for i in inventory.modules.get(module, [])]

system_sdk_modules = struct(
    entries = _entries,
    read = lambda repository_ctx: _decode(repository_ctx.read(_INVENTORY)),
    decode = _decode,
    aliases = _aliases,
    inventory = _inventory,
    sdk_constraints = _sdk_constraints,
)
