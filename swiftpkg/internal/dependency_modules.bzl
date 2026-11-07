"""Resolve package-provided module names for each SDK platform.

This is a pure metadata operation. Repository reads stay in sdk_inference_context. Product
closures are cached per package/product/platform across all consuming targets.
"""

load("//config_settings/spm/platform:platforms.bzl", spm_platforms = "platforms")
load(":pkginfo_targets.bzl", "pkginfo_targets")

def _field(value, name, default = None):
    return value.get(name, default) if type(value) == "dict" else getattr(value, name, default)

def _active(reference, platform):
    condition = _field(reference, "condition")
    platforms = spm_platforms.supported(_field(condition, "platforms", [])) if condition else []

    # Match bzl_selects' treatment of trait-only and unsupported-platform lists.
    return not platforms or platform in ["macos" if p == "driverkit" else p for p in platforms]

def _index(info):
    return struct(
        name = _field(info, "name"),
        targets = {_field(t, "name"): t for t in _field(info, "targets", [])},
        products = {_field(p, "name"): _field(p, "targets") for p in _field(info, "products", [])},
        dependencies = {_field(d, "name").lower(): _field(d, "identity") for d in _field(info, "dependencies", [])},
    )

def _reference(dependency):
    for kind in ["target", "by_name", "product"]:
        ref = _field(dependency, kind)
        if ref:
            return kind, ref
    return None, None

def _local_roots(index, kind, ref):
    if kind == "target":
        return [_field(ref, "target_name")]
    if kind == "by_name":
        name = _field(ref, "name")
        return [name] if name in index.targets else index.products.get(name, [])
    if kind == "product" and _field(ref, "dep_name") == index.name:
        return index.products.get(_field(ref, "product_name"), [])
    return []

def _walk(index, roots, platform):
    pending = roots
    visited = {}
    external = []
    for _ in range(len(index.targets) + 1):
        if not pending:
            break
        current = pending
        pending = []
        for name in current:
            if name in visited or name not in index.targets:
                continue
            target = index.targets[name]
            visited[name] = target
            for dependency in _field(target, "dependencies", []):
                kind, ref = _reference(dependency)
                if not ref or not _active(ref, platform):
                    continue
                local = _local_roots(index, kind, ref)
                if local:
                    pending.extend(local)
                elif kind in ["product", "by_name"]:
                    external.append((kind, ref))
    return struct(targets = visited.values(), external = external)

def _external_key(index, kind, ref):
    name = _field(ref, "dep_name") if kind == "product" else _field(ref, "name")
    identity = index.dependencies.get(name.lower()) if name else None
    product = _field(ref, "product_name") if kind == "product" else name
    return (identity, product) if identity else None

def _resolve(pkg_info, metadata, platforms):
    local = _index(pkg_info)
    indexes = {identity: _index(info) for identity, info in metadata.items()}
    products = {}
    result = {}
    missing = {}

    # Each package/product is visited once per consuming target and platform.
    # Use a worklist rather than recursion (which Starlark does not support).
    limit = 1
    for index in indexes.values():
        limit += len(index.products)
    for target in pkg_info.targets:
        if target.type == "test":
            continue
        result[target.name] = {}
        for platform in sorted(platforms):
            closure = _walk(local, [target.name], platform)
            modules = {pkginfo_targets.module_name(t): True for t in closure.targets}
            pending = [_external_key(local, kind, ref) for kind, ref in closure.external]
            visited = {}
            for _ in range(limit):
                if not pending:
                    break
                current = pending
                pending = []
                for key in current:
                    if key == None or key in visited:
                        continue
                    visited[key] = True
                    identity, product_name = key
                    if identity not in indexes:
                        missing[identity] = True
                        continue
                    index = indexes[identity]
                    cache_key = (identity, product_name, platform)
                    if cache_key not in products:
                        products[cache_key] = _walk(index, index.products.get(product_name, []), platform)
                    product = products[cache_key]
                    modules.update({pkginfo_targets.module_name(t): True for t in product.targets})
                    pending.extend([_external_key(index, kind, ref) for kind, ref in product.external])
            result[target.name][platform] = sorted(modules)
    return struct(modules = result, missing = sorted(missing))

dependency_modules = struct(
    for_package = lambda pkg_info, metadata, platforms: _resolve(pkg_info, metadata, platforms).modules,
    resolve = _resolve,
)
