"""Prepare source inference from an optional package-context SDK inventory.

The provider and consumer can be merged independently. Until the provider adds
sdk_modules to package contexts, inference remains a no-op even when opted in.
"""

load("@bazel_skylib//lib:structs.bzl", "structs")
load(":bazel_repo_names.bzl", "bazel_repo_names")
load(":compiler_imports.bzl", "compiler_imports")
load(":dependency_modules.bzl", "dependency_modules")
load(":pkg_ctxs.bzl", "pkg_ctxs")
load(":pkginfo_targets.bzl", "pkginfo_targets")
load(":repository_utils.bzl", "repository_utils")

def _prepare(repository_ctx, pkg_ctx):
    inventory = getattr(pkg_ctx, "sdk_modules", None)
    if not pkg_ctx.system_sdk_deps or inventory == None or not inventory.modules:
        return pkg_ctx
    if not getattr(inventory, "scan", None):
        fail("SDK inference requires the compiler-profile inventory provider (schema 2).")
    pkg_info = pkg_ctx.pkg_info

    # Read only resolved dependencies actually referenced by built targets, once
    # each. Product names are not module names: follow their exported target graph.
    repos_label = getattr(repository_ctx.attr, "package_repos", None)
    declared = json.decode(repository_ctx.read(repos_label)).get("repo_names", []) if repos_label else []
    own_name = repository_utils.package_name(repository_ctx)
    prefix = repository_ctx.name.removesuffix(own_name)
    metadata = {}
    for identity in pkg_ctxs.referenced_dependency_identities(pkg_info):
        repo = bazel_repo_names.from_identity(identity)
        if repo not in declared:
            continue
        label = Label("@@{}{}//:pkg_info.json".format(prefix, repo))
        if repository_ctx.path(label).exists:
            metadata[identity] = json.decode(repository_ctx.read(label))
    platforms = {entry["platform"]: True for entry in inventory.conditions.values()}
    fields = structs.to_dict(pkg_ctx)
    fields["dependency_modules"] = dependency_modules.for_package(pkg_info, metadata, platforms)
    fields["source_scans"] = {}
    context = struct(**fields)

    # The provider fingerprints watched SDK/compiler files once. Reading its
    # modules.json records that digest without walking every SDK for each package.
    reports = {}
    for target in pkg_info.targets:
        if target.type == "test" or not target.swift_src_info:
            continue
        sources = pkginfo_targets.srcs(target)
        if not sources:
            continue
        for src in sources:
            contents = repository_ctx.read(src)
            if "canImport" in contents and ("_version" in contents or "_underlyingVersion" in contents):
                fail("Version-qualified canImport needs module version metadata unavailable during repository fetching ({}). Disable system_sdk_deps and supply manual deps for this package.".format(src))
        records = compiler_imports.scan(repository_ctx, context, target, fields["dependency_modules"].get(target.name, {}))
        fields["source_scans"][target.name] = records
        reports[target.name] = {
            "linked_frameworks": [
                {"condition": setting.condition, "values": setting.values}
                for setting in target.linker_settings.linked_frameworks
            ] if target.linker_settings else [],
            "scans": records,
            "sources": sorted(sources),
        }
    repository_ctx.file("sdk_inference.json", json.encode_indent({
        "compiler": inventory.scan,
        "schema_version": 1,
        "targets": reports,
    }))
    return struct(**fields)

sdk_inference_context = struct(prepare = _prepare)
