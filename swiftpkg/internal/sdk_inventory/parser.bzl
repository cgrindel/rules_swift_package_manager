"""Pure parser for the supported rules_swift generated SDK BUILD format."""

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
    for block in ("\n" + contents).split("\nconfig_setting(\n")[1:]:
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
                constraints.append(value)
            elif line == 'visibility = ["//visibility:private"],':
                continue
            else:
                return None
        if not name or not name.endswith("_sdk") or not constraints or in_constraints:
            return None
        result[":" + name] = constraints
    return result

system_sdk_inventory = struct(aliases = _aliases, inventory = _inventory, sdk_constraints = _sdk_constraints)
