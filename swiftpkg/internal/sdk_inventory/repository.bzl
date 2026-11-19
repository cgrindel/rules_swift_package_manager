"""Read a committed SDK cache without consulting the fetch host."""

load("//swiftpkg/internal:build_files.bzl", "build_files")
load(":profiles.bzl", "sdk_scan_profiles")
load(":render.bzl", "sdk_inventory_render")

_INVENTORY = Label("@rspm_sdk_inventory//:modules.json")
_EMPTY = struct(modules = {}, conditions = {}, diagnostic = "", scan = {})

def _error(reason, generator):
    fail("SDK cache: {}. Run bazel run {} -- --request <settings.json> --output <cache.json>, then commit the cache.".format(reason, generator))

def _validate(cache, request, generator):
    if type(cache) != "dict" or cache.get("schema_version") != 3:
        _error("unsupported cache schema (expected 3)", generator)
    if cache.get("request") != request:
        _error("generation settings changed", generator)
    targets = request.get("targets", {})
    if not targets:
        _error("no SDK profiles", generator)
    for sdk, triple in targets.items():
        reason = sdk_scan_profiles.error(sdk, triple)
        if reason:
            _error(reason, generator)
    for key in ["xcode_version", "swift_version"]:
        if not cache.get(key) or type(cache[key]) != "string":
            _error("missing " + key, generator)
    if not cache.get("fingerprints") or not cache.get("modules"):
        _error("missing input fingerprints or SDK modules", generator)
    for name, refs in cache["modules"].items():
        if not name or type(refs) != "list" or not refs or any([sdk not in targets for sdk in refs]):
            _error("invalid SDK availability for " + name, generator)
    return cache

def _repo_impl(ctx):
    if not ctx.attr.cache or not ctx.attr.request:
        _error("configure sdk_inventory.configure(cache = ..., request = ...) with source-file labels", ctx.attr.generator)
    for label in [ctx.attr.cache, ctx.attr.request]:
        if not ctx.path(label).exists:
            _error("missing " + str(label), ctx.attr.generator)
    request = json.decode(ctx.read(ctx.attr.request))

    # Normalize optional fields just as Go's Request does when it is serialized.
    request = dict({"defines": None, "exclude_modules": None, "full_sdk_tracking": False}, **request)
    cache = _validate(json.decode(ctx.read(ctx.attr.cache)), request, ctx.attr.generator)
    result = sdk_inventory_render.render(
        cache,
        ctx.name,
        {c: str(Label("//config_settings/spm/configuration:" + c)) for c in ["debug", "release"]},
        lambda label: str(Label(label)),
    )
    build_files.write(ctx, result.build, "")
    ctx.file("modules.json", json.encode(result.metadata))

_sdk_inventory_repo = repository_rule(
    implementation = _repo_impl,
    attrs = {
        "cache": attr.label(allow_single_file = [".json"]),
        "generator": attr.string(default = "@rules_swift_package_manager//swiftpkg:update_sdk_cache"),
        "request": attr.label(allow_single_file = [".json"]),
    },
)

_CONFIGURE_ATTRS = {
    "cache": attr.label(mandatory = True, allow_single_file = [".json"], doc = "Committed SDK cache generated explicitly with bazel run."),
    "generator": attr.string(default = "@rules_swift_package_manager//swiftpkg:update_sdk_cache", doc = "Runnable target named in missing/stale cache diagnostics."),
    "request": attr.label(mandatory = True, allow_single_file = [".json"], doc = "Portable SDK profiles and generation settings used to validate the cache."),
}

def _extension_impl(module_ctx):
    tags = []
    for mod in module_ctx.modules:
        if mod.tags.configure and not mod.is_root:
            fail("Only the root module may configure the SDK cache.")
        tags.extend(mod.tags.configure)
    if len(tags) > 1:
        fail("Specify at most one sdk_inventory.configure tag.")
    args = {name: getattr(tags[0], name) for name in _CONFIGURE_ATTRS} if tags else {}
    _sdk_inventory_repo(name = "rspm_sdk_inventory", **args)

sdk_inventory = module_extension(
    implementation = _extension_impl,
    tag_classes = {"configure": tag_class(attrs = _CONFIGURE_ATTRS)},
)

def _decode(contents):
    metadata = json.decode(contents)
    if metadata.get("schema_version") != sdk_inventory_render.schema_version:
        fail("Unsupported RSPM SDK inventory schema; regenerate the SDK cache.")
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
    validate = _validate,
    generate = _repo_impl,
)
