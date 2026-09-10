"""Package platform version helpers for minimum OS transition wrappers."""

load(
    "//config_settings/spm/platform:platforms.bzl",
    spm_platforms = "platforms",
)
load(":minimum_os_platforms.bzl", "minimum_os_platforms")
load(":pkginfo_dependencies.bzl", "pkginfo_dependencies")
load(":pkginfos.bzl", "target_types")

_MINIMUM_OS_CONFIG_BY_PLATFORM = minimum_os_platforms.by_platform()

def _fallback(platform_name):
    platform_name = spm_platforms.normalize(platform_name)
    config = _MINIMUM_OS_CONFIG_BY_PLATFORM.get(platform_name)
    if config == None:
        fail("No fallback minimum OS is defined for platform '{}'.".format(platform_name))
    return config.fallback

def _version_tuple(value):
    components = str(value).split(".") + ["0", "0", "0"]
    return tuple([int(x if x.isdigit() else "0") for x in components[0:3]])

def _is_higher(version, other):
    return _version_tuple(version) > _version_tuple(other)

def _by_platform(pkg_info, dep_versions = []):
    """Derives the effective minimum OS version for each supported platform.

    SwiftPM compiles a module against the highest deployment target found
    among the declaring package and the packages it depends on. Mirror that by
    starting from the declared (or fallback) versions and raising each platform
    to the highest version required by any dependency. A version is never
    lowered.

    Args:
        pkg_info: A `struct` as returned by `pkginfos.new`.
        dep_versions: A `list` of `dict` values as returned by this function,
            one per package dependency, holding the effective versions of
            that dependency.

    Returns:
        A `dict` mapping supported platform names to version `string` values.
    """
    versions = {
        platform_name: config.fallback
        for platform_name, config in _MINIMUM_OS_CONFIG_BY_PLATFORM.items()
    }

    for platform in pkg_info.platforms:
        if platform.name in _MINIMUM_OS_CONFIG_BY_PLATFORM:
            versions[platform.name] = platform.version

    for dep in dep_versions:
        for platform_name, version in dep.items():
            if platform_name not in _MINIMUM_OS_CONFIG_BY_PLATFORM:
                continue
            if version and _is_higher(version, versions[platform_name]):
                versions[platform_name] = version

    return versions

def _dependency_versions(dep_versions_by_identity, pkg_info, dep_name, product_name):
    """Looks up the effective versions exported by an external dependency.

    Args:
        dep_versions_by_identity: A `dict` mapping package identities to a
            `dict` with `package` and `products` keys as written by
            `pkg_ctxs` (see `minimum_os_versions.new_exported`).
        pkg_info: A `struct` as returned by `pkginfos.new`.
        dep_name: The dependency (package) name referenced by a target dependency.
        product_name: The referenced product name.

    Returns:
        A `dict` of platform versions, or `None` when the dependency is not
        known or exports nothing.
    """
    dep = pkginfo_dependencies.get_by_name(pkg_info.dependencies, dep_name)
    if dep == None:
        return None
    exported = dep_versions_by_identity.get(dep.identity)
    if exported == None:
        return None
    versions = exported.get("products", {}).get(product_name)
    if versions == None:
        # Unknown product: fall back to the package-wide maximum, which is
        # never lower than any of its products.
        versions = exported.get("package")
    return versions

def _for_targets(pkg_info, dep_versions_by_identity = {}):
    """Derives effective minimum OS versions for each non-test target.

    Mirrors SwiftPM, which raises a module's deployment target to the
    highest floor among its package, the packages providing the products it
    depends on, and the in-package targets it depends on (transitively).

    Args:
        pkg_info: A `struct` as returned by `pkginfos.new`.
        dep_versions_by_identity: A `dict` mapping dependency package
            identities to the `dict` those packages exported (see
            `minimum_os_versions.new_exported`).

    Returns:
        A `struct` with `targets` (target name to versions), `products`
        (product name to versions) and `package` (the package-wide maximum).
    """
    declared = _by_platform(pkg_info)
    targets = [t for t in pkg_info.targets if t.type != target_types.test]
    products_by_name = {p.name: p for p in pkg_info.products}
    target_names = [t.name for t in targets]
    versions_by_target = {name: declared for name in target_names}

    def _product_targets_versions(product):
        return [
            versions_by_target[tname]
            for tname in product.targets
            if tname in versions_by_target
        ]

    def _dep_versions_list(target_dep):
        if target_dep.target:
            tname = target_dep.target.target_name
            return [versions_by_target[tname]] if tname in versions_by_target else []
        if target_dep.product:
            ref = target_dep.product
            if ref.dep_name == pkg_info.name:
                product = products_by_name.get(ref.product_name)
                return _product_targets_versions(product) if product else []
            versions = _dependency_versions(
                dep_versions_by_identity,
                pkg_info,
                ref.dep_name,
                ref.product_name,
            )
            return [versions] if versions else []
        if target_dep.by_name:
            name = target_dep.by_name.name
            if name in versions_by_target:
                return [versions_by_target[name]]
            if name in products_by_name:
                return _product_targets_versions(products_by_name[name])
            versions = _dependency_versions(dep_versions_by_identity, pkg_info, name, name)
            return [versions] if versions else []
        return []

    # In-package target dependencies form a DAG, so at most one pass per
    # target is needed to reach a fixed point.
    for _ in range(len(targets) + 1):
        changed = False
        for target in targets:
            dep_versions = []
            for target_dep in target.dependencies:
                dep_versions.extend(_dep_versions_list(target_dep))
            versions = _by_platform(pkg_info, dep_versions)
            if versions != versions_by_target[target.name]:
                versions_by_target[target.name] = versions
                changed = True
        if not changed:
            break

    return struct(
        targets = versions_by_target,
        products = {
            name: _by_platform(pkg_info, _product_targets_versions(product))
            for name, product in products_by_name.items()
        },
        package = _by_platform(pkg_info, versions_by_target.values()),
    )

def _new_exported(effective):
    """Creates the JSON-encodable `dict` a package exports for its dependents.

    Args:
        effective: A `struct` as returned by `minimum_os_versions.for_targets`.

    Returns:
        A `dict` with `package` and `products` keys.
    """
    return {
        "package": effective.package,
        "products": effective.products,
    }

def _transition_attrs(versions):
    """Maps effective platform versions to `spm_minimum_os_*` wrapper attributes.

    Args:
        versions: A `dict` as returned by `minimum_os_versions.by_platform`.

    Returns:
        A `dict` of wrapper attribute names to version `string` values.
    """
    return {
        config.attr_name: versions[platform_name]
        for platform_name, config in _MINIMUM_OS_CONFIG_BY_PLATFORM.items()
    }

minimum_os_versions = struct(
    by_platform = _by_platform,
    fallback = _fallback,
    for_targets = _for_targets,
    is_higher = _is_higher,
    new_exported = _new_exported,
    transition_attrs = _transition_attrs,
)
