"""Lazy SDK metadata for one explicitly configured compiler environment."""

load(":inputs.bzl", "sdk_inventory_inputs")
load(":parser.bzl", "system_sdk_inventory")
load(":render.bzl", "sdk_inventory_render")

_SDK_BUILD = Label("@system_sdk//:BUILD.bazel")
_INVENTORY = Label("@rspm_sdk_inventory//:modules.json")
_EMPTY = struct(modules = {}, conditions = {}, diagnostic = "", scan = {})

def _error(reason):
    fail("SDK inference: {}. Configure sdk_inventory.configure(...) or disable system_sdk_deps for this package.".format(reason))

def _execute(ctx, args, developer_dir):
    result = ctx.execute(args, environment = {"DEVELOPER_DIR": developer_dir, "SDKROOT": ""})
    if result.return_code:
        _error("{} failed:\n{}".format(args, result.stderr))
    return result.stdout.strip()

def _selection(hub, version_output):
    """Choose exactly one hub branch before touching any per-Xcode repository."""
    version = None
    build = None
    for line in version_output.splitlines():
        if line.startswith("Xcode "):
            version = line[len("Xcode "):].strip().split(".")
        elif line.startswith("Build version "):
            build = line[len("Build version "):].strip()
    if not version or not build:
        _error("unrecognized xcodebuild -version output")
    version = version + ["0"] * max(0, 3 - len(version))
    condition = ":xcode_" + "_".join(version + [build.replace("-", "_")])
    branches = hub.get("all_modules")
    if not branches or condition not in branches:
        _error("the configured Xcode ({}) is absent from the system_sdk hub".format(condition))
    actual = branches[condition]
    repo, sep, target = actual.partition("//:")
    if not sep or not repo.startswith("@system_sdk_xcode_") or target != "all_modules":
        _error("unsupported SDK hub repository mapping")
    return repo

def _read_upstream(ctx, sdk_build, version_output):
    canonical = sdk_build.repo_name
    if not canonical.endswith("+system_sdk+system_sdk"):
        _error("overridden system_sdk mappings are not supported by this temporary adapter")
    hub = system_sdk_inventory.aliases(ctx.read(sdk_build))
    if hub == None or "all_modules" not in hub:
        _error("unsupported SDK hub format (missing all_modules aliases)")
    repo = _selection(hub, version_output)
    prefix = canonical[:-len("system_sdk")]
    label = Label("@@{}{}//:BUILD.bazel".format(prefix, repo[1:]))
    contents = ctx.read(label)
    aliases = system_sdk_inventory.aliases(contents)
    constraints = system_sdk_inventory.sdk_constraints(contents)
    if aliases == None or not aliases.get("all_modules") or not constraints:
        _error("unsupported SDK aliases or constraints in " + repo)
    inventory = system_sdk_inventory.inventory(hub, {repo: aliases})
    if not inventory:
        _error("unrecognized or empty SDK module inventory")
    for entries in inventory.values():
        if any([e["sdk_condition"] not in constraints for e in entries]):
            _error("missing SDK constraint definition")
    return struct(modules = inventory, constraints = {repo: constraints})

def _repo_impl(ctx):
    # Repository rules cannot inspect a build's --xcode_version, platform or
    # swiftcopts. Require root-owned scan profiles rather than guessing them.
    if not ctx.attr.targets:
        _error("no compiler scan profiles were configured")
    if ctx.os.name.lower() != "mac os x":
        _error("compiler-driven Apple SDK inference requires a macOS fetch host")
    developer_dir = ctx.getenv("DEVELOPER_DIR") or _execute(ctx, ["/usr/bin/xcode-select", "-p"], "")
    if ctx.attr.developer_dir and ctx.path(ctx.attr.developer_dir).realpath != ctx.path(developer_dir).realpath:
        _error("developer_dir must match DEVELOPER_DIR/xcode-select so the upstream hub and package scans use the same Xcode")
    if ctx.getenv("TOOLCHAINS") not in [None, "", "XcodeDefault", "com.apple.dt.toolchain.XcodeDefault"]:
        _error("custom TOOLCHAINS are not supported by these Xcode SDK scan profiles")
    version = _execute(ctx, ["/usr/bin/xcrun", "xcodebuild", "-version"], developer_dir)
    upstream = _read_upstream(ctx, _SDK_BUILD, version)
    swiftc = _execute(ctx, ["/usr/bin/xcrun", "--find", "swiftc"], developer_dir)
    ctx.watch(swiftc)
    sdks = {}
    for sdk in sorted(ctx.attr.targets):
        sdks[sdk] = _execute(ctx, ["/usr/bin/xcrun", "--sdk", sdk.lower(), "--show-sdk-path"], developer_dir)
        ctx.watch(sdks[sdk] + "/SDKSettings.json")
    roots = [swiftc, str(ctx.path(swiftc).dirname.dirname) + "/lib"] + sdks.values()
    for sdk_path in sdks.values():
        platform_developer = str(ctx.path(sdk_path).dirname.dirname)
        for suffix in ["/Library/Frameworks", "/usr/lib"]:
            path = platform_developer + suffix
            ctx.watch(path)
            if ctx.path(path).exists:
                roots.append(path)
    ctx.report_progress("Tracking configured SDK and compiler inputs")
    inputs = sdk_inventory_inputs.files(ctx, roots)
    ctx.file("scan_inputs.json", json.encode(inputs))
    ctx.read(ctx.attr._fingerprint)
    digest = _execute(ctx, ["/usr/bin/python3", str(ctx.path(ctx.attr._fingerprint)), str(ctx.path("scan_inputs.json"))], developer_dir)
    scan = {
        "defines": ctx.attr.defines,
        "developer_dir": developer_dir,
        "inputs_digest": digest,
        "sdks": sdks,
        "swift_version": _execute(ctx, [swiftc, "--version"], developer_dir),
        "swiftc": swiftc,
        "targets": ctx.attr.targets,
        "xcode_version": version,
    }
    result = sdk_inventory_render.render(
        upstream,
        ctx.name,
        str(_SDK_BUILD).removesuffix("BUILD.bazel"),
        {c: str(Label("//config_settings/spm/configuration:" + c)) for c in ["debug", "release"]},
        lambda label: str(Label(label)),
        scan,
    )
    if sorted(result.metadata["conditions"]) != sorted(ctx.attr.targets):
        _error("a configured scan SDK is absent from the rules_swift inventory; also configure system_sdk.configure_sdks")
    ctx.file("BUILD.bazel", result.build)
    ctx.file("modules.json", json.encode(result.metadata))

_sdk_inventory_repo = repository_rule(
    implementation = _repo_impl,
    attrs = {
        "defines": attr.string_list(),
        "developer_dir": attr.string(),
        "targets": attr.string_dict(),
        "_fingerprint": attr.label(default = Label(":fingerprint.py"), allow_single_file = True),
    },
    configure = True,
)

def _extension_impl(module_ctx):
    tags = []
    for mod in module_ctx.modules:
        if mod.tags.configure and not mod.is_root:
            fail("Only the root module may configure SDK inference scan profiles.")
        tags.extend(mod.tags.configure)
    if len(tags) > 1:
        fail("Specify at most one sdk_inventory.configure tag.")
    args = {}
    if tags:
        args = {"defines": tags[0].defines, "developer_dir": tags[0].developer_dir, "targets": tags[0].targets}
    _sdk_inventory_repo(name = "rspm_sdk_inventory", **args)

sdk_inventory = module_extension(
    implementation = _extension_impl,
    tag_classes = {"configure": tag_class(attrs = {
        "defines": attr.string_list(doc = "Additional Swift conditional compilation flags shared by the scan profiles."),
        "developer_dir": attr.string(doc = "Xcode Developer directory. Defaults to DEVELOPER_DIR, then xcode-select."),
        "targets": attr.string_dict(mandatory = True, doc = "SDK name to compiler target triple; only these configurations are inferred."),
    })},
)

def _decode(contents):
    metadata = json.decode(contents)
    if metadata.get("schema_version") != 2:
        fail("Unsupported RSPM SDK inventory schema: {}".format(metadata.get("schema_version")))
    return struct(
        modules = metadata["modules"],
        conditions = metadata["conditions"],
        diagnostic = metadata["diagnostic"],
        scan = metadata["scan"],
    )

system_sdk_modules = struct(
    read = lambda ctx: _decode(ctx.read(_INVENTORY)),
    decode = _decode,
    empty = _EMPTY,
    read_upstream = _read_upstream,
    selection = _selection,
)
