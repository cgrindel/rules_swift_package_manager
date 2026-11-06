"""Prepare source inference from an optional package-context SDK inventory.

The provider and consumer can be merged independently. Until the provider adds
sdk_modules to package contexts, inference remains a no-op even when opted in.
"""

load("@bazel_skylib//lib:structs.bzl", "structs")
load(":bazel_repo_names.bzl", "bazel_repo_names")
load(":dependency_modules.bzl", "dependency_modules")
load(":pkg_ctxs.bzl", "pkg_ctxs")
load(":repository_utils.bzl", "repository_utils")

def _prepare(repository_ctx, pkg_ctx):
    inventory = getattr(pkg_ctx, "sdk_modules", None)
    if not pkg_ctx.system_sdk_deps or inventory == None or not inventory.modules:
        return pkg_ctx
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
    return struct(**fields)

sdk_inference_context = struct(prepare = _prepare)
